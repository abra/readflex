import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:review_scheduler/review_scheduler.dart';

void main() {
  const studyDay = StudyDay();
  // 12:00 local on a Monday; the clock may be given any instant below.
  final noon = DateTime(2026, 10, 26, 12);
  late DateTime now;
  late ReviewScheduler scheduler;

  setUp(() {
    now = noon;
    scheduler = ReviewScheduler(clock: () => now);
  });

  ReviewResult review(
    FsrsCardData current,
    Rating rating, {
    double desiredRetention = defaultDesiredRetention,
  }) => scheduler.computeReview(
    itemId: 'w1',
    itemType: ReviewableType.dictionary,
    currentFsrs: current,
    rating: rating,
    desiredRetention: desiredRetention,
  );

  /// A card in review, last seen [daysAgo] study days before [now].
  FsrsCardData inReview({
    double stability = 10,
    double difficulty = 5,
    int daysAgo = 10,
  }) => FsrsCardData(
    state: FsrsState.review,
    stability: stability,
    difficulty: difficulty,
    reps: 3,
    lastReviewAt: studyDay
        .startAfter(now, -daysAgo)
        .add(
          const Duration(hours: 8),
        ),
    nextReviewAt: now,
  );

  group('clock', () {
    test('timestamps come from the injected clock', () {
      final result = review(const FsrsCardData(), Rating.good);

      expect(result.fsrs.lastReviewAt, now.toUtc());
      expect(result.log.reviewedAt, now.toUtc());
      expect(result.fsrs.nextReviewAt!.isAfter(now), isTrue);
    });

    test('stores instants in UTC', () {
      final result = review(const FsrsCardData(), Rating.good);

      expect(result.fsrs.lastReviewAt!.isUtc, isTrue);
      expect(result.fsrs.nextReviewAt!.isUtc, isTrue);
    });
  });

  group('single learning step', () {
    test('Good on a new card graduates straight to review', () {
      final result = review(const FsrsCardData(), Rating.good);

      expect(result.fsrs.state, FsrsState.review);
      expect(result.fsrs.scheduledDays, greaterThanOrEqualTo(1));
      expect(result.fsrs.nextReviewAt!.isAfter(now), isTrue);
    });

    test('Again on a new card stays in learning for minutes', () {
      final result = review(const FsrsCardData(), Rating.again);

      expect(result.fsrs.state, FsrsState.learning);
      expect(result.fsrs.scheduledDays, 0);
      expect(
        result.fsrs.nextReviewAt,
        now.toUtc().add(const Duration(minutes: 10)),
      );
    });

    test('Hard on a new card waits one and a half steps', () {
      final result = review(const FsrsCardData(), Rating.hard);

      expect(result.fsrs.state, FsrsState.learning);
      expect(
        result.fsrs.nextReviewAt,
        now.toUtc().add(const Duration(minutes: 15)),
      );
    });
  });

  group('study days', () {
    test('a review after midnight counts as the same day', () {
      now = DateTime(2026, 10, 27, 0, 10);
      final card = inReview().copyWith(
        lastReviewAt: DateTime(2026, 10, 26, 23, 50).toUtc(),
      );

      final result = review(card, Rating.good);

      expect(result.fsrs.elapsedDays, 0);
      expect(result.log.elapsedDays, 0);
    });

    test('a review after 04:00 counts a new day', () {
      now = DateTime(2026, 10, 27, 4, 1);
      final card = inReview().copyWith(
        lastReviewAt: DateTime(2026, 10, 27, 3, 59).toUtc(),
      );

      expect(review(card, Rating.good).fsrs.elapsedDays, 1);
    });

    test(
      'the same instant to the package in two places gives two intervals',
      () {
        // 23:50 → 00:10 is a short-term review (no day passed); the model's
        // same-day formula keeps the card's stability close to where it was,
        // while a full day's gap lets it grow.
        now = DateTime(2026, 10, 27, 0, 10);
        final sameDay = review(
          inReview().copyWith(
            lastReviewAt: DateTime(2026, 10, 26, 23, 50).toUtc(),
          ),
          Rating.good,
        );
        final nextDay = review(
          inReview().copyWith(
            lastReviewAt: DateTime(2026, 10, 25, 23, 50).toUtc(),
          ),
          Rating.good,
        );

        expect(sameDay.fsrs.elapsedDays, 0);
        expect(nextDay.fsrs.elapsedDays, 1);
        expect(sameDay.fsrs.stability, isNot(nextDay.fsrs.stability));
      },
    );

    test('a card due in N days comes due when that study day starts', () {
      now = DateTime(2026, 10, 26, 23, 50);
      final result = review(inReview(), Rating.good);
      final days = result.fsrs.scheduledDays;

      expect(days, greaterThanOrEqualTo(1));
      expect(
        result.fsrs.nextReviewAt,
        DateTime(2026, 10, 26 + days, 4).toUtc(),
      );
      expect(studyDay.between(now, result.fsrs.nextReviewAt!), days);
    });

    test('a learning step is due by the clock, not the day', () {
      now = DateTime(2026, 10, 26, 23, 55);
      final result = review(const FsrsCardData(), Rating.again);

      expect(
        result.fsrs.nextReviewAt,
        now.toUtc().add(const Duration(minutes: 10)),
      );
    });

    test('a last review in the future counts as today', () {
      final card = inReview().copyWith(
        lastReviewAt: now.add(const Duration(days: 3)).toUtc(),
      );
      expect(review(card, Rating.good).fsrs.elapsedDays, 0);
    });
  });

  group('intervals', () {
    test('grow strictly with the rating for a card in review', () {
      for (final stability in [0.5, 1.0, 1.2, 2.0, 10.0, 60.0]) {
        for (final difficulty in [1.0, 5.0, 9.0]) {
          final card = inReview(stability: stability, difficulty: difficulty);
          final hard = review(card, Rating.hard).fsrs.scheduledDays;
          final good = review(card, Rating.good).fsrs.scheduledDays;
          final easy = review(card, Rating.easy).fsrs.scheduledDays;
          final reason = 's=$stability d=$difficulty';

          expect(hard, greaterThanOrEqualTo(1), reason: reason);
          expect(good, greaterThan(hard), reason: reason);
          expect(easy, greaterThan(good), reason: reason);
        }
      }
    });

    test('Good and Easy on a new card are ordered too', () {
      final good = review(const FsrsCardData(), Rating.good).fsrs.scheduledDays;
      final easy = review(const FsrsCardData(), Rating.easy).fsrs.scheduledDays;

      expect(good, greaterThanOrEqualTo(1));
      expect(easy, greaterThan(good));
    });

    test('never pass the maximum interval', () {
      final card = inReview(stability: 100000, difficulty: 1, daysAgo: 300);

      for (final rating in [Rating.hard, Rating.good, Rating.easy]) {
        expect(
          review(card, rating).fsrs.scheduledDays,
          defaultMaximumIntervalDays,
          reason: rating.name,
        );
      }
    });

    test('a custom maximum interval caps every rating', () {
      scheduler = ReviewScheduler(maximumIntervalDays: 30, clock: () => now);
      final card = inReview(stability: 500, daysAgo: 100);

      expect(review(card, Rating.easy).fsrs.scheduledDays, 30);
      expect(review(card, Rating.good).fsrs.scheduledDays, 30);
    });

    test('Again on a review card relearns in minutes and counts a lapse', () {
      final result = review(inReview(), Rating.again);

      expect(result.fsrs.state, FsrsState.relearning);
      expect(result.fsrs.scheduledDays, 0);
      expect(result.fsrs.lapses, 1);
      expect(
        result.fsrs.nextReviewAt,
        now.toUtc().add(const Duration(minutes: 10)),
      );
    });
  });

  group('desired retention', () {
    test('a lower target waits longer, a higher one comes back sooner', () {
      final card = inReview(stability: 20);
      final lighter = review(card, Rating.good, desiredRetention: 0.8);
      final balanced = review(card, Rating.good);
      final stronger = review(card, Rating.good, desiredRetention: 0.95);

      expect(
        lighter.fsrs.scheduledDays,
        greaterThan(balanced.fsrs.scheduledDays),
      );
      expect(
        balanced.fsrs.scheduledDays,
        greaterThan(stronger.fsrs.scheduledDays),
      );
    });

    test('is held to the accepted range', () {
      expect(clampDesiredRetention(0.5), minDesiredRetention);
      expect(clampDesiredRetention(0.99), maxDesiredRetention);
      expect(clampDesiredRetention(0.85), 0.85);

      final card = inReview(stability: 20);
      expect(
        review(card, Rating.good, desiredRetention: 0.1).fsrs.scheduledDays,
        review(
          card,
          Rating.good,
          desiredRetention: minDesiredRetention,
        ).fsrs.scheduledDays,
      );
    });

    test('does not change the memory state, only the gap', () {
      final card = inReview(stability: 20);
      final lighter = review(card, Rating.good, desiredRetention: 0.8).fsrs;
      final stronger = review(card, Rating.good, desiredRetention: 0.95).fsrs;

      expect(lighter.stability, stronger.stability);
      expect(lighter.difficulty, stronger.difficulty);
    });
  });

  group('previewIntervals', () {
    test('covers every rating and orders them again ≤ hard ≤ good ≤ easy', () {
      final preview = scheduler.previewIntervals(const FsrsCardData());

      expect(preview.keys, containsAll(Rating.values));
      expect(preview[Rating.again]!, lessThanOrEqualTo(preview[Rating.hard]!));
      expect(preview[Rating.hard]!, lessThanOrEqualTo(preview[Rating.good]!));
      expect(preview[Rating.good]!, lessThanOrEqualTo(preview[Rating.easy]!));
    });

    test('shows whole days for review and minutes for a learning step', () {
      final preview = scheduler.previewIntervals(const FsrsCardData());

      expect(preview[Rating.again], const Duration(minutes: 10));
      expect(preview[Rating.hard], const Duration(minutes: 15));
      expect(preview[Rating.good]!.inDays, greaterThanOrEqualTo(1));
      expect(preview[Rating.good]!.inHours % 24, 0);
    });

    test('matches what computeReview schedules, late at night too', () {
      now = DateTime(2026, 10, 26, 23, 50);
      final card = inReview();
      final preview = scheduler.previewIntervals(card);

      for (final rating in [Rating.hard, Rating.good, Rating.easy]) {
        expect(
          preview[rating]!.inDays,
          review(card, rating).fsrs.scheduledDays,
          reason: rating.name,
        );
      }
    });

    test('follows the desired retention', () {
      final card = inReview(stability: 20);
      final lighter = scheduler.previewIntervals(card, desiredRetention: 0.8);
      final stronger = scheduler.previewIntervals(card, desiredRetention: 0.95);

      expect(lighter[Rating.good]!, greaterThan(stronger[Rating.good]!));
    });

    test('records nothing', () {
      const current = FsrsCardData();
      scheduler.previewIntervals(current);
      expect(current.reps, 0);
      expect(current.state, FsrsState.newCard);
    });
  });
}
