import 'dart:math' as math;

import 'package:domain_models/domain_models.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:uuid/uuid.dart' show Uuid;

import 'study_day.dart';

const _uuid = Uuid();

/// Probability of recall a card is scheduled to have when it comes due.
/// Anki's default; lower means fewer reviews, higher means more.
const double defaultDesiredRetention = 0.9;

/// The range [ReviewScheduler] accepts for a desired retention; values
/// outside it either never bring cards back or bring them back daily.
const double minDesiredRetention = 0.7;
const double maxDesiredRetention = 0.97;

/// The longest gap scheduling may put between two reviews. A year: the
/// model's own cap of 100 years lets a card vanish for the reader's lifetime.
const int defaultMaximumIntervalDays = 365;

/// [desiredRetention] held to the accepted range.
double clampDesiredRetention(double desiredRetention) =>
    desiredRetention.clamp(minDesiredRetention, maxDesiredRetention);

/// Result of running FSRS scheduling on a reviewable item.
class ReviewResult {
  const ReviewResult({required this.fsrs, required this.log});

  /// Updated FSRS data to persist on the item.
  final FsrsCardData fsrs;

  /// Review log entry to persist.
  final ReviewLog log;
}

/// FSRS-6 scheduling shared by every reviewable item type, on the `fsrs`
/// package with the app's rules around it:
///
/// - Days are [StudyDay]s: the days elapsed since the last review and the
///   day a card comes due follow the 04:00 boundary, not the clock. The
///   package counts calendar days between two instants, so it is handed a
///   last-review instant exactly that many whole days before now.
/// - A card rated Good graduates to review at once (one learning and one
///   relearning step of ten minutes); Readflex stores no learning step.
/// - Day-level intervals are at least one day, grow with the rating (Hard
///   below Good below Easy) and never pass [maximumIntervalDays]; a card due
///   in N days comes due when that study day starts.
/// - Fuzzing is off, so the interval under a rating button is the one that
///   gets recorded.
/// - The desired retention comes with each call, from the reader's
///   settings; the package scheduler for each value is kept.
class ReviewScheduler {
  ReviewScheduler({
    this.maximumIntervalDays = defaultMaximumIntervalDays,
    this.studyDay = const StudyDay(),
    DateTime Function()? clock,
  }) : assert(maximumIntervalDays >= 1),
       _clock = clock ?? DateTime.now;

  final int maximumIntervalDays;
  final StudyDay studyDay;
  final DateTime Function() _clock;
  final _schedulers = <double, fsrs.Scheduler>{};

  /// Computes new FSRS data and a review log for the given item.
  ReviewResult computeReview({
    required String itemId,
    required ReviewableType itemType,
    required FsrsCardData currentFsrs,
    required Rating rating,
    int? reviewDurationMs,
    double desiredRetention = defaultDesiredRetention,
  }) {
    final now = _clock().toUtc();
    final elapsedDays = _elapsedDays(currentFsrs, now);
    final outcome = _outcomes(currentFsrs, now, desiredRetention)[rating]!;

    // Retrievability is only meaningful for cards already in the review
    // state.
    final retrievability = currentFsrs.state == FsrsState.review
        ? _schedulerFor(desiredRetention).getCardRetrievability(
            _cardFor(itemId, currentFsrs, now, elapsedDays),
            currentDateTime: now,
          )
        : 0.0;

    final newLapses =
        (rating == Rating.again && currentFsrs.state == FsrsState.review)
        ? currentFsrs.lapses + 1
        : currentFsrs.lapses;

    final newFsrs = FsrsCardData(
      state: _fromFsrsState(outcome.card.state),
      stability: outcome.card.stability ?? 0.0,
      difficulty: outcome.card.difficulty ?? 0.0,
      retrievability: retrievability,
      reps: currentFsrs.reps + 1,
      lapses: newLapses,
      lastReviewAt: now,
      nextReviewAt: outcome.due,
      scheduledDays: outcome.days,
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
      scheduledDays: outcome.days,
      elapsedDays: elapsedDays,
      reviewDurationMs: reviewDurationMs,
      reviewedAt: now,
    );

    return ReviewResult(fsrs: newFsrs, log: log);
  }

  /// How long each rating would postpone the next review, without recording
  /// anything: whole days for a card going to review, minutes for a learning
  /// step. Shown under the rating buttons.
  Map<Rating, Duration> previewIntervals(
    FsrsCardData currentFsrs, {
    double desiredRetention = defaultDesiredRetention,
  }) {
    final now = _clock().toUtc();
    final outcomes = _outcomes(currentFsrs, now, desiredRetention);
    return {
      for (final MapEntry(key: rating, value: outcome) in outcomes.entries)
        rating: outcome.days > 0
            ? Duration(days: outcome.days)
            : outcome.due.difference(now),
    };
  }

  /// What every rating would do to [current] at [now]: one package call per
  /// rating, then the day-level results made monotonic and capped, and put
  /// on study-day starts.
  Map<Rating, _Outcome> _outcomes(
    FsrsCardData current,
    DateTime now,
    double desiredRetention,
  ) {
    final scheduler = _schedulerFor(desiredRetention);
    final elapsedDays = _elapsedDays(current, now);
    final outcomes = <Rating, _Outcome>{};
    var floor = 0;
    for (final rating in Rating.values) {
      final card = scheduler
          .reviewCard(
            _cardFor('outcome', current, now, elapsedDays),
            _toFsrsRating(rating),
            reviewDateTime: now,
          )
          .card;
      if (card.state != fsrs.State.review) {
        outcomes[rating] = _Outcome(card: card, due: card.due, days: 0);
        continue;
      }
      // The package schedules `now + N days`; N is read back exactly. Each
      // rating adds at least a day to the one below it, up to the cap.
      final modelDays = card.due.difference(now).inDays;
      final days = math.min(
        math.max(modelDays, floor + 1),
        maximumIntervalDays,
      );
      floor = days;
      outcomes[rating] = _Outcome(
        card: card,
        due: studyDay.startAfter(now, days).toUtc(),
        days: days,
      );
    }
    return outcomes;
  }

  int _elapsedDays(FsrsCardData current, DateTime now) {
    final last = current.lastReviewAt;
    if (last == null) return 0;
    final days = studyDay.between(last, now);
    return days < 0 ? 0 : days;
  }

  fsrs.Scheduler _schedulerFor(double desiredRetention) =>
      _schedulers.putIfAbsent(
        clampDesiredRetention(desiredRetention),
        () => fsrs.Scheduler(
          desiredRetention: clampDesiredRetention(desiredRetention),
          maximumInterval: maximumIntervalDays,
          learningSteps: const [Duration(minutes: 10)],
          relearningSteps: const [Duration(minutes: 10)],
          // Previewed intervals must match the recorded ones.
          enableFuzzing: false,
        ),
      );

  // stability/difficulty are 0.0 for never-reviewed items; the fsrs package
  // reads null as "compute initial values". The last review is placed
  // [elapsedDays] whole days before [now], so the package's calendar-day
  // count equals the study-day count.
  fsrs.Card _cardFor(
    String itemId,
    FsrsCardData current,
    DateTime now,
    int elapsedDays,
  ) => fsrs.Card(
    cardId: itemId.hashCode,
    state: _toFsrsState(current.state),
    stability: current.stability == 0.0 ? null : current.stability,
    difficulty: current.difficulty == 0.0 ? null : current.difficulty,
    due: current.nextReviewAt?.toUtc() ?? now,
    lastReview: current.lastReviewAt == null
        ? null
        : now.subtract(Duration(days: elapsedDays)),
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

/// What one rating does to a card: the package's card, when it comes due,
/// and the whole days scheduled (0 for a learning step in minutes).
class _Outcome {
  const _Outcome({required this.card, required this.due, required this.days});

  final fsrs.Card card;
  final DateTime due;
  final int days;
}
