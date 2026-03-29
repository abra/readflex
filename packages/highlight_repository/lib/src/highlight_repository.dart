import 'package:domain_models/domain_models.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:local_storage/local_storage.dart';
import 'package:uuid/uuid.dart' show Uuid;

import 'mappers/highlight_to_domain.dart';
import 'mappers/highlight_to_storage.dart';
import 'mappers/review_log_to_storage.dart';

const _uuid = Uuid();

/// Domain repository for text highlights with FSRS v6 scheduling.
class HighlightRepository {
  HighlightRepository({
    required AppDatabase database,
    fsrs.Scheduler? scheduler,
  }) : _dao = database.highlightsDao,
       _scheduler = scheduler ?? fsrs.Scheduler();

  final HighlightsDao _dao;
  final fsrs.Scheduler _scheduler;

  // ─── CRUD ───

  Future<List<Highlight>> getHighlights() async {
    final rows = await _dao.allHighlights();
    return rows.map((r) => r.toDomainModel()).toList();
  }

  Future<List<Highlight>> getHighlightsBySource(String sourceId) async {
    final rows = await _dao.highlightsBySource(sourceId);
    return rows.map((r) => r.toDomainModel()).toList();
  }

  Future<List<Highlight>> getDueHighlights() async {
    final now = DateTime.now().toUtc().toIso8601String();
    final rows = await _dao.dueHighlights(now);
    return rows.map((r) => r.toDomainModel()).toList();
  }

  Future<List<Highlight>> getDueHighlightsBySource(String sourceId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final rows = await _dao.dueHighlightsBySource(sourceId, now);
    return rows.map((r) => r.toDomainModel()).toList();
  }

  Future<Highlight?> getHighlightById(String id) async {
    final row = await _dao.highlightById(id);
    return row?.toDomainModel();
  }

  Future<Highlight> addHighlight({
    required String sourceId,
    required SourceType sourceType,
    required String text,
    String? note,
    String? cfiRange,
    int? pageNumber,
    double? scrollOffset,
    HighlightColor color = HighlightColor.yellow,
  }) async {
    final highlight = Highlight(
      id: _uuid.v4(),
      sourceId: sourceId,
      sourceType: sourceType,
      text: text,
      note: note,
      cfiRange: cfiRange,
      pageNumber: pageNumber,
      scrollOffset: scrollOffset,
      color: color,
      createdAt: DateTime.now(),
    );
    await _dao.insertHighlight(highlight.toStorageModel());
    return highlight;
  }

  Future<Highlight> updateHighlight(Highlight highlight) async {
    await _dao.updateHighlight(highlight.toStorageModel());
    return highlight;
  }

  Future<void> deleteHighlight(String id) async {
    await _dao.deleteHighlight(id);
  }

  Future<void> deleteHighlightsBySource(String sourceId) async {
    await _dao.deleteHighlightsBySource(sourceId);
  }

  // ─── Review (FSRS) ───

  Future<Highlight> recordReview(
    Highlight highlight,
    Rating rating, {
    int? reviewDurationMs,
  }) async {
    final now = DateTime.now().toUtc();
    final oldFsrs = highlight.fsrs;

    final fsrsCard = fsrs.Card(cardId: highlight.id.hashCode)
      ..state = _toFsrsState(oldFsrs.state)
      ..stability = oldFsrs.stability == 0.0 ? null : oldFsrs.stability
      ..difficulty = oldFsrs.difficulty == 0.0 ? null : oldFsrs.difficulty
      ..due = oldFsrs.nextReviewAt?.toUtc() ?? now
      ..lastReview = oldFsrs.lastReviewAt?.toUtc();

    final result = _scheduler.reviewCard(
      fsrsCard,
      _toFsrsRating(rating),
      reviewDateTime: now,
      reviewDuration: reviewDurationMs,
    );
    final updated = result.card;

    final elapsedDays = oldFsrs.lastReviewAt != null
        ? now.difference(oldFsrs.lastReviewAt!).inDays
        : 0;
    final scheduledDays = updated.due.difference(now).inDays;
    final retrievability = oldFsrs.state == FsrsState.review
        ? _scheduler.getCardRetrievability(fsrsCard)
        : 0.0;

    final newReps = oldFsrs.reps + 1;
    final newLapses =
        (rating == Rating.again && oldFsrs.state == FsrsState.review)
        ? oldFsrs.lapses + 1
        : oldFsrs.lapses;

    final updatedHighlight = highlight.copyWith(
      fsrs: FsrsCardData(
        state: _fromFsrsState(updated.state),
        stability: updated.stability ?? 0.0,
        difficulty: updated.difficulty ?? 0.0,
        retrievability: retrievability,
        reps: newReps,
        lapses: newLapses,
        lastReviewAt: now,
        nextReviewAt: updated.due,
        scheduledDays: scheduledDays,
        elapsedDays: elapsedDays,
      ),
    );

    final log = ReviewLog(
      id: _uuid.v4(),
      itemId: highlight.id,
      itemType: ReviewableType.highlight,
      rating: rating,
      stateBefore: oldFsrs.state,
      stabilityBefore: oldFsrs.stability,
      difficultyBefore: oldFsrs.difficulty,
      retrievabilityAtReview: retrievability,
      scheduledDays: scheduledDays,
      elapsedDays: elapsedDays,
      reviewDurationMs: reviewDurationMs,
      reviewedAt: now,
    );

    await _dao.updateHighlight(updatedHighlight.toStorageModel());
    await _dao.insertReviewLog(log.toStorageModel());

    return updatedHighlight;
  }

  // ─── Mapping helpers ───

  static fsrs.State _toFsrsState(FsrsState state) => switch (state) {
    FsrsState.newCard => fsrs.State.learning,
    FsrsState.learning => fsrs.State.learning,
    FsrsState.review => fsrs.State.review,
    FsrsState.relearning => fsrs.State.relearning,
  };

  static FsrsState _fromFsrsState(fsrs.State state) => switch (state) {
    fsrs.State.learning => FsrsState.learning,
    fsrs.State.review => FsrsState.review,
    fsrs.State.relearning => FsrsState.relearning,
  };

  static fsrs.Rating _toFsrsRating(Rating rating) => switch (rating) {
    Rating.again => fsrs.Rating.again,
    Rating.hard => fsrs.Rating.hard,
    Rating.good => fsrs.Rating.good,
    Rating.easy => fsrs.Rating.easy,
  };
}
