import 'package:article_repository/article_repository.dart';
import 'package:book_repository/book_repository.dart';
import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fsrs_repository/fsrs_repository.dart';
import 'package:highlight_repository/highlight_repository.dart';
import 'package:preferences_service/preferences_service.dart';

import 'practice_item.dart';
import 'practice_item_loader.dart';
import 'practice_review_eligibility.dart';
import 'practice_source_index.dart';

part 'review_session_event.dart';
part 'review_session_state.dart';

/// One review session: the due queue, one card at a time, each rating
/// recorded through FSRS as it is given.
///
/// The queue honours the Profile settings: highlights only when enabled, and
/// never-reviewed cards only up to the daily limit less those already
/// reviewed today. [sourceId] narrows the queue to one source. [ahead] lets
/// a caught-up reader review the cards due soonest instead.
class ReviewSessionBloc extends Bloc<ReviewSessionEvent, ReviewSessionState> {
  ReviewSessionBloc({
    required this._fsrsRepository,
    required DictionaryRepository dictionaryRepository,
    required HighlightRepository highlightRepository,
    required this._bookRepository,
    required this._preferencesService,
    this._articleRepository,
    this.sourceId,
    this.ahead = false,
  }) : _loader = PracticeItemLoader(
         dictionaryRepository: dictionaryRepository,
         highlightRepository: highlightRepository,
       ),
       super(const ReviewSessionState()) {
    // Related writes and restarts share one queue, regardless of the app's
    // default transformer. Card identities reject stale queued gestures.
    on<ReviewSessionEvent>(
      _onEvent,
      transformer: (events, mapper) => events.asyncExpand(mapper),
    );
  }

  /// Cards per session at most.
  static const sessionLimit = 50;

  /// Cards a caught-up reader reviews ahead of time.
  static const aheadLimit = 20;

  final String? sourceId;
  final bool ahead;
  final FsrsRepository _fsrsRepository;
  final BookRepository _bookRepository;
  final ArticleRepository? _articleRepository;
  final PreferencesService _preferencesService;
  final PracticeItemLoader _loader;

  /// The reader's memory target, read once when the session starts so every
  /// preview and rating in it schedules the same way.
  double _desiredRetention = Preferences.defaultPracticeDesiredRetention;
  int _cardRevision = 0;

  Future<void> _onEvent(
    ReviewSessionEvent event,
    Emitter<ReviewSessionState> emit,
  ) async {
    switch (event) {
      case ReviewSessionStarted():
        await _onStarted(event, emit);
      case ReviewSessionAnswerRevealed():
        _onRevealed(event, emit);
      case ReviewSessionCardRated():
        await _onRated(event, emit);
      case ReviewSessionCardRemoved():
        await _onRemoved(event, emit);
      case ReviewSessionAgainRequested():
        _onAgainRequested(event, emit);
    }
  }

  Future<void> _onStarted(
    ReviewSessionStarted event,
    Emitter<ReviewSessionState> emit,
  ) async {
    emit(const ReviewSessionState());
    try {
      final prefs = _preferencesService.current;
      final eligibility = PracticeReviewEligibility(
        reviewHighlights: prefs.practiceReviewHighlights,
      );
      _desiredRetention = prefs.practiceDesiredRetention;
      final (rows, sources, stats) = await (
        _dueRows(eligibility),
        PracticeSourceIndex.load(
          bookRepository: _bookRepository,
          articleRepository: _articleRepository,
        ),
        _fsrsRepository.getStats(),
      ).wait;
      if (emit.isDone) return;
      var newBudget = prefs.practiceNewCardsPerDay - stats.newReviewedToday;
      final queue = <ReviewItem>[];
      for (final row in rows) {
        if (!eligibility.includes(row.itemType)) continue;
        if (row.fsrs.state == FsrsState.newCard) {
          if (newBudget <= 0) continue;
          newBudget--;
        }
        queue.add(row);
        if (queue.length >= sessionLimit) break;
      }
      final items = await _loader.resolve(queue, sources);
      if (emit.isDone) return;
      emit(_begin(items));
    } catch (e, st) {
      addError(e, st);
      if (emit.isDone) return;
      emit(state.copyWith(status: ReviewSessionStatus.failure));
    }
  }

  Future<List<ReviewItem>> _dueRows(
    PracticeReviewEligibility eligibility,
  ) async {
    final source = sourceId;
    if (ahead) {
      final all = [
        for (final type in eligibility.types)
          ...await _fsrsRepository.getReviewItems(type),
      ];
      final scoped = source == null
          ? all
          : [
              for (final row in all)
                if (row.sourceId == source) row,
            ];
      // Soonest due first; never-reviewed cards have no date and come last.
      scoped.sort((a, b) {
        final da = a.fsrs.nextReviewAt;
        final db = b.fsrs.nextReviewAt;
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      });
      return scoped.take(aheadLimit).toList();
    }
    final (newRows, reviewedRows) = await (
      _dueRowsWithStates(eligibility, const {FsrsState.newCard}),
      _dueRowsWithStates(eligibility, const {
        FsrsState.learning,
        FsrsState.review,
        FsrsState.relearning,
      }),
    ).wait;
    // A full prefix of new cards must not hide due reviews after the daily
    // allowance is exhausted. Both reads remain bounded by the session size.
    return _mergeDueRows(newRows, reviewedRows);
  }

  Future<List<ReviewItem>> _dueRowsWithStates(
    PracticeReviewEligibility eligibility,
    Set<FsrsState> states,
  ) {
    final source = sourceId;
    return source == null
        ? _fsrsRepository.getDueItems(
            types: eligibility.types,
            states: states,
            limit: sessionLimit,
          )
        : _fsrsRepository.getDueItemsBySource(
            source,
            types: eligibility.types,
            states: states,
            limit: sessionLimit,
          );
  }

  static List<ReviewItem> _mergeDueRows(
    List<ReviewItem> newRows,
    List<ReviewItem> reviewedRows,
  ) {
    final merged = <ReviewItem>[];
    var newIndex = 0;
    var reviewedIndex = 0;
    // Each SQL result is already ordered by nextReviewAt, nulls first.
    while (newIndex < newRows.length && reviewedIndex < reviewedRows.length) {
      final newDate = newRows[newIndex].fsrs.nextReviewAt;
      final reviewedDate = reviewedRows[reviewedIndex].fsrs.nextReviewAt;
      if (newDate == null ||
          reviewedDate != null && !newDate.isAfter(reviewedDate)) {
        merged.add(newRows[newIndex++]);
      } else {
        merged.add(reviewedRows[reviewedIndex++]);
      }
    }
    return merged
      ..addAll(newRows.skip(newIndex))
      ..addAll(reviewedRows.skip(reviewedIndex));
  }

  ReviewSessionState _begin(List<PracticeItem> items) {
    if (items.isEmpty) {
      return const ReviewSessionState(status: ReviewSessionStatus.empty);
    }
    return ReviewSessionState(
      status: ReviewSessionStatus.reviewing,
      items: items,
      cardRevision: ++_cardRevision,
      intervals: _fsrsRepository.previewIntervals(
        items.first.fsrs,
        desiredRetention: _desiredRetention,
      ),
    );
  }

  void _onRevealed(
    ReviewSessionAnswerRevealed event,
    Emitter<ReviewSessionState> emit,
  ) {
    if (!_isCurrentCard(event.card) || state.current is! PracticeWordItem) {
      return;
    }
    emit(state.copyWith(revealed: true));
  }

  Future<void> _onRated(
    ReviewSessionCardRated event,
    Emitter<ReviewSessionState> emit,
  ) async {
    final item = state.current;
    if (item == null ||
        !_isCurrentCard(event.card) ||
        (item is PracticeWordItem && !state.revealed)) {
      return;
    }
    emit(state.copyWith(isSaving: true));
    late final FsrsCardData updatedFsrs;
    try {
      updatedFsrs = await _fsrsRepository.recordReview(
        itemId: item.itemId,
        itemType: item.itemType,
        rating: event.rating,
        sourceId: item.sourceId,
        desiredRetention: _desiredRetention,
      );
    } on NotFoundException {
      // Content can disappear while the cached card remains on screen.
      if (!emit.isDone) _dropCurrentCard(emit);
      return;
    } catch (e, st) {
      addError(e, st);
      if (emit.isDone) return;
      emit(
        state.copyWith(status: ReviewSessionStatus.failure, isSaving: false),
      );
      return;
    }
    if (emit.isDone) return;
    _advance(
      emit,
      ratings: {...state.ratings, item.itemId: event.rating},
      again: event.rating == Rating.again
          ? [...state.again, item.withFsrs(updatedFsrs)]
          : state.again,
    );
  }

  Future<void> _onRemoved(
    ReviewSessionCardRemoved event,
    Emitter<ReviewSessionState> emit,
  ) async {
    final item = state.current;
    if (item == null || !_isCurrentCard(event.card)) return;
    emit(state.copyWith(isSaving: true));
    try {
      await _fsrsRepository.deleteReviewItem(item.itemId);
    } catch (e, st) {
      addError(e, st);
      if (emit.isDone) return;
      emit(
        state.copyWith(status: ReviewSessionStatus.failure, isSaving: false),
      );
      return;
    }
    if (emit.isDone) return;
    _dropCurrentCard(emit);
  }

  void _dropCurrentCard(Emitter<ReviewSessionState> emit) {
    final items = [...state.items]..removeAt(state.index);
    if (state.index >= items.length) {
      emit(
        state.copyWith(
          status: state.ratings.isEmpty
              ? ReviewSessionStatus.empty
              : ReviewSessionStatus.completed,
          items: items,
          isSaving: false,
          revealed: false,
          intervals: const {},
        ),
      );
      return;
    }
    final index = state.index;
    emit(
      state.copyWith(
        items: items,
        index: index,
        cardRevision: ++_cardRevision,
        isSaving: false,
        revealed: false,
        intervals: _fsrsRepository.previewIntervals(
          items[index].fsrs,
          desiredRetention: _desiredRetention,
        ),
      ),
    );
  }

  void _onAgainRequested(
    ReviewSessionAgainRequested event,
    Emitter<ReviewSessionState> emit,
  ) {
    if (state.status != ReviewSessionStatus.completed || state.again.isEmpty) {
      return;
    }
    emit(_begin(state.again));
  }

  bool _isCurrentCard(ReviewSessionCardIdentity card) =>
      state.status == ReviewSessionStatus.reviewing &&
      !state.isSaving &&
      state.cardIdentity == card;

  void _advance(
    Emitter<ReviewSessionState> emit, {
    required Map<String, Rating> ratings,
    required List<PracticeItem> again,
  }) {
    final next = state.index + 1;
    if (next >= state.items.length) {
      emit(
        state.copyWith(
          status: ReviewSessionStatus.completed,
          ratings: ratings,
          again: again,
          revealed: false,
          isSaving: false,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        index: next,
        cardRevision: ++_cardRevision,
        isSaving: false,
        revealed: false,
        ratings: ratings,
        again: again,
        intervals: _fsrsRepository.previewIntervals(
          state.items[next].fsrs,
          desiredRetention: _desiredRetention,
        ),
      ),
    );
  }
}
