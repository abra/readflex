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

/// FSRS v6 scheduling shared by every reviewable item type.
///
/// Readflex stores no learning step, so the scheduler runs one learning
/// and one relearning step: a card rated Good graduates to review at once
/// instead of looping on the first step forever.
class ReviewScheduler {
  ReviewScheduler({fsrs.Scheduler? scheduler, DateTime Function()? clock})
    : _scheduler =
          scheduler ??
          fsrs.Scheduler(
            learningSteps: const [Duration(minutes: 10)],
            relearningSteps: const [Duration(minutes: 10)],
            // Previewed intervals must match the recorded ones.
            enableFuzzing: false,
          ),
      _clock = clock ?? DateTime.now;

  final fsrs.Scheduler _scheduler;
  final DateTime Function() _clock;

  /// Computes new FSRS data and a review log for the given item.
  ReviewResult computeReview({
    required String itemId,
    required ReviewableType itemType,
    required FsrsCardData currentFsrs,
    required Rating rating,
    int? reviewDurationMs,
  }) {
    final now = _clock().toUtc();
    final card = _cardFor(itemId, currentFsrs, now);
    final updated = _scheduler
        .reviewCard(
          card,
          _toFsrsRating(rating),
          reviewDateTime: now,
          reviewDuration: reviewDurationMs,
        )
        .card;

    final elapsedDays = currentFsrs.lastReviewAt != null
        ? now.difference(currentFsrs.lastReviewAt!.toUtc()).inDays
        : 0;
    final scheduledDays = updated.due.difference(now).inDays;

    // Retrievability is only meaningful for cards already in the review state.
    final retrievability = currentFsrs.state == FsrsState.review
        ? _scheduler.getCardRetrievability(card, currentDateTime: now)
        : 0.0;

    final newLapses =
        (rating == Rating.again && currentFsrs.state == FsrsState.review)
        ? currentFsrs.lapses + 1
        : currentFsrs.lapses;

    final newFsrs = FsrsCardData(
      state: _fromFsrsState(updated.state),
      stability: updated.stability ?? 0.0,
      difficulty: updated.difficulty ?? 0.0,
      retrievability: retrievability,
      reps: currentFsrs.reps + 1,
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

  /// How long each rating would postpone the next review, without recording
  /// anything. Shown under the rating buttons.
  Map<Rating, Duration> previewIntervals(FsrsCardData currentFsrs) {
    final now = _clock().toUtc();
    return {
      for (final rating in Rating.values)
        rating: _scheduler
            .reviewCard(
              _cardFor('preview', currentFsrs, now),
              _toFsrsRating(rating),
              reviewDateTime: now,
            )
            .card
            .due
            .difference(now),
    };
  }

  // stability/difficulty are 0.0 for never-reviewed items; the fsrs package
  // reads null as "compute initial values".
  fsrs.Card _cardFor(String itemId, FsrsCardData current, DateTime now) =>
      fsrs.Card(
        cardId: itemId.hashCode,
        state: _toFsrsState(current.state),
        stability: current.stability == 0.0 ? null : current.stability,
        difficulty: current.difficulty == 0.0 ? null : current.difficulty,
        due: current.nextReviewAt?.toUtc() ?? now,
        lastReview: current.lastReviewAt?.toUtc(),
      );

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
