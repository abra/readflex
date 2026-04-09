import 'package:domain_models/domain_models.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:uuid/uuid.dart' show Uuid;

const _uuid = Uuid();

/// Result of running FSRS scheduling on a reviewable item.
class ReviewResult {
  const ReviewResult({required this.fsrs, required this.log});

  /// Updated FSRS data to persist on the item.
  final FsrsCardData fsrs;

  /// Review log entry to persist.
  final ReviewLog log;
}

/// Shared FSRS v6 scheduling logic used by all repositories.
///
/// Each repository delegates the pure scheduling computation here,
/// then persists the results using its own DAO.
class ReviewScheduler {
  ReviewScheduler({fsrs.Scheduler? scheduler})
    : _scheduler = scheduler ?? fsrs.Scheduler();

  final fsrs.Scheduler _scheduler;

  /// Computes new FSRS data and a review log for the given item.
  ///
  /// [itemId] and [itemType] identify the reviewed item.
  /// [currentFsrs] is the item's current FSRS state.
  /// [rating] is the user's self-assessment (again/hard/good/easy).
  ///
  /// Returns a [ReviewResult] with the updated [FsrsCardData] and a
  /// [ReviewLog] ready to be persisted.
  ReviewResult computeReview({
    required String itemId,
    required ReviewableType itemType,
    required FsrsCardData currentFsrs,
    required Rating rating,
    int? reviewDurationMs,
  }) {
    final now = DateTime.now().toUtc();

    // Map domain state → fsrs package types.
    // stability/difficulty default to 0.0 in FsrsCardData (never-reviewed
    // items). The fsrs package interprets null as "compute initial values",
    // so we convert 0.0 → null here to trigger first-review initialization.
    final fsrsCard = fsrs.Card(cardId: itemId.hashCode)
      ..state = _toFsrsState(currentFsrs.state)
      ..stability = currentFsrs.stability == 0.0 ? null : currentFsrs.stability
      ..difficulty = currentFsrs.difficulty == 0.0
          ? null
          : currentFsrs.difficulty
      ..due = currentFsrs.nextReviewAt?.toUtc() ?? now
      ..lastReview = currentFsrs.lastReviewAt?.toUtc();

    final result = _scheduler.reviewCard(
      fsrsCard,
      _toFsrsRating(rating),
      reviewDateTime: now,
      reviewDuration: reviewDurationMs,
    );
    final updated = result.card;

    final elapsedDays = currentFsrs.lastReviewAt != null
        ? now.difference(currentFsrs.lastReviewAt!).inDays
        : 0;
    final scheduledDays = updated.due.difference(now).inDays;

    // Retrievability is only meaningful for cards already in the review state.
    final retrievability = currentFsrs.state == FsrsState.review
        ? _scheduler.getCardRetrievability(fsrsCard)
        : 0.0;

    final newReps = currentFsrs.reps + 1;
    final newLapses =
        (rating == Rating.again && currentFsrs.state == FsrsState.review)
        ? currentFsrs.lapses + 1
        : currentFsrs.lapses;

    final newFsrs = FsrsCardData(
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
    );

    final log = ReviewLog(
      id: _uuid.v4(),
      itemId: itemId,
      itemType: itemType,
      rating: rating,
      stateBefore: currentFsrs.state,
      stabilityBefore: currentFsrs.stability,
      difficultyBefore: currentFsrs.difficulty,
      retrievabilityAtReview: retrievability,
      scheduledDays: scheduledDays,
      elapsedDays: elapsedDays,
      reviewDurationMs: reviewDurationMs,
      reviewedAt: now,
    );

    return ReviewResult(fsrs: newFsrs, log: log);
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
