import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:review_scheduler/review_scheduler.dart';

void main() {
  final fixedNow = DateTime.utc(2026, 10, 26, 12);
  late ReviewScheduler scheduler;

  setUp(() {
    scheduler = ReviewScheduler(clock: () => fixedNow);
  });

  group('clock', () {
    test('timestamps come from the injected clock', () {
      final result = scheduler.computeReview(
        itemId: 'w1',
        itemType: ReviewableType.dictionary,
        currentFsrs: const FsrsCardData(),
        rating: Rating.good,
      );

      expect(result.fsrs.lastReviewAt, fixedNow);
      expect(result.log.reviewedAt, fixedNow);
      expect(result.fsrs.nextReviewAt!.isAfter(fixedNow), isTrue);
    });

    test('accepts a local-time clock', () {
      final local = ReviewScheduler(clock: () => DateTime(2026, 10, 26, 9));
      final result = local.computeReview(
        itemId: 'w1',
        itemType: ReviewableType.dictionary,
        currentFsrs: const FsrsCardData(),
        rating: Rating.good,
      );

      expect(result.fsrs.lastReviewAt!.isUtc, isTrue);
    });
  });

  group('single learning step', () {
    test('Good on a new card graduates straight to review', () {
      final result = scheduler.computeReview(
        itemId: 'w1',
        itemType: ReviewableType.dictionary,
        currentFsrs: const FsrsCardData(),
        rating: Rating.good,
      );

      expect(result.fsrs.state, FsrsState.review);
      expect(
        result.fsrs.nextReviewAt!.difference(fixedNow).inHours,
        greaterThanOrEqualTo(24),
      );
    });

    test('Again on a new card stays in learning for minutes', () {
      final result = scheduler.computeReview(
        itemId: 'w1',
        itemType: ReviewableType.dictionary,
        currentFsrs: const FsrsCardData(),
        rating: Rating.again,
      );

      expect(result.fsrs.state, FsrsState.learning);
      expect(
        result.fsrs.nextReviewAt!.difference(fixedNow).inMinutes,
        lessThanOrEqualTo(10),
      );
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

    test('matches what computeReview schedules', () {
      final preview = scheduler.previewIntervals(const FsrsCardData());
      final good = scheduler.computeReview(
        itemId: 'w1',
        itemType: ReviewableType.dictionary,
        currentFsrs: const FsrsCardData(),
        rating: Rating.good,
      );

      expect(
        good.fsrs.nextReviewAt!.difference(fixedNow),
        preview[Rating.good],
      );
    });

    test('records nothing', () {
      const current = FsrsCardData();
      scheduler.previewIntervals(current);
      expect(current.reps, 0);
      expect(current.state, FsrsState.newCard);
    });
  });
}
