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
    required FsrsRepository fsrsRepository,
    required DictionaryRepository dictionaryRepository,
    required HighlightRepository highlightRepository,
    required BookRepository bookRepository,
    required PreferencesService preferencesService,
    ArticleRepository? articleRepository,
    this.sourceId,
    this.ahead = false,
  }) : _fsrsRepository = fsrsRepository,
       _bookRepository = bookRepository,
       _articleRepository = articleRepository,
       _preferencesService = preferencesService,
       _loader = PracticeItemLoader(
         dictionaryRepository: dictionaryRepository,
         highlightRepository: highlightRepository,
         fsrsRepository: fsrsRepository,
       ),
       super(const ReviewSessionState()) {
    on<ReviewSessionStarted>(_onStarted);
    on<ReviewSessionAnswerRevealed>(_onRevealed);
    on<ReviewSessionCardRated>(_onRated);
    on<ReviewSessionCardRemoved>(_onRemoved);
    on<ReviewSessionAgainRequested>(_onAgainRequested);
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

  Future<void> _onStarted(
    ReviewSessionStarted event,
    Emitter<ReviewSessionState> emit,
  ) async {
    emit(const ReviewSessionState());
    try {
      final prefs = _preferencesService.current;
      final (rows, sources, stats) = await (
        _dueRows(),
        PracticeSourceIndex.load(
          bookRepository: _bookRepository,
          articleRepository: _articleRepository,
        ),
        _fsrsRepository.getStats(),
      ).wait;
      var newBudget = prefs.practiceNewCardsPerDay - stats.newReviewedToday;
      final queue = <ReviewItem>[];
      for (final row in rows) {
        if (!prefs.practiceReviewHighlights &&
            row.itemType == ReviewableType.highlight) {
          continue;
        }
        if (row.fsrs.state == FsrsState.newCard) {
          if (newBudget <= 0) continue;
          newBudget--;
        }
        queue.add(row);
        if (queue.length >= sessionLimit) break;
      }
      final items = await _loader.resolve(queue, sources);
      emit(_begin(items));
    } catch (e, st) {
      addError(e, st);
      emit(state.copyWith(status: ReviewSessionStatus.failure));
    }
  }

  Future<List<ReviewItem>> _dueRows() async {
    final source = sourceId;
    if (ahead) {
      final all = [
        for (final type in [
          ReviewableType.dictionary,
          ReviewableType.highlight,
        ])
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
    return source == null
        ? _fsrsRepository.getDueItems(limit: sessionLimit * 2)
        : _fsrsRepository.getDueItemsBySource(source, limit: sessionLimit * 2);
  }

  ReviewSessionState _begin(List<PracticeItem> items) {
    if (items.isEmpty) {
      return const ReviewSessionState(status: ReviewSessionStatus.empty);
    }
    return ReviewSessionState(
      status: ReviewSessionStatus.reviewing,
      items: items,
      intervals: _fsrsRepository.previewIntervals(items.first.fsrs),
    );
  }

  void _onRevealed(
    ReviewSessionAnswerRevealed event,
    Emitter<ReviewSessionState> emit,
  ) {
    if (state.status != ReviewSessionStatus.reviewing) return;
    emit(state.copyWith(revealed: true));
  }

  Future<void> _onRated(
    ReviewSessionCardRated event,
    Emitter<ReviewSessionState> emit,
  ) async {
    final item = state.current;
    if (item == null || state.status != ReviewSessionStatus.reviewing) return;
    try {
      await _fsrsRepository.recordReview(
        itemId: item.itemId,
        itemType: item.itemType,
        rating: event.rating,
        sourceId: item.sourceId,
      );
    } catch (e, st) {
      addError(e, st);
      emit(state.copyWith(status: ReviewSessionStatus.failure));
      return;
    }
    _advance(
      emit,
      ratings: {...state.ratings, item.itemId: event.rating},
      again: event.rating == Rating.again
          ? [...state.again, item]
          : state.again,
    );
  }

  Future<void> _onRemoved(
    ReviewSessionCardRemoved event,
    Emitter<ReviewSessionState> emit,
  ) async {
    final item = state.current;
    if (item == null || state.status != ReviewSessionStatus.reviewing) return;
    try {
      await _fsrsRepository.deleteReviewItem(item.itemId);
    } catch (e, st) {
      addError(e, st);
    }
    final items = [...state.items]..removeAt(state.index);
    if (items.isEmpty) {
      emit(
        state.copyWith(
          status: state.ratings.isEmpty
              ? ReviewSessionStatus.empty
              : ReviewSessionStatus.completed,
          items: items,
        ),
      );
      return;
    }
    final index = state.index.clamp(0, items.length - 1);
    emit(
      state.copyWith(
        items: items,
        index: index,
        revealed: false,
        intervals: _fsrsRepository.previewIntervals(items[index].fsrs),
      ),
    );
  }

  void _onAgainRequested(
    ReviewSessionAgainRequested event,
    Emitter<ReviewSessionState> emit,
  ) {
    if (state.again.isEmpty) return;
    emit(_begin(state.again));
  }

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
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        index: next,
        revealed: false,
        ratings: ratings,
        again: again,
        intervals: _fsrsRepository.previewIntervals(state.items[next].fsrs),
      ),
    );
  }
}
