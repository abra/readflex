import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:review_scheduler/review_scheduler.dart';

void main() {
  group('ReviewScheduler.computeReview', () {
    late ReviewScheduler scheduler;

    setUp(() {
      scheduler = ReviewScheduler();
    });

    ReviewResult review({
      FsrsCardData current = const FsrsCardData(),
      Rating rating = Rating.good,
      String itemId = 'item-1',
      ReviewableType itemType = ReviewableType.flashcard,
      int? durationMs,
    }) {
      return scheduler.computeReview(
        itemId: itemId,
        itemType: itemType,
        currentFsrs: current,
        rating: rating,
        reviewDurationMs: durationMs,
      );
    }

    group('first review of a new card', () {
      test('transitions out of the new state', () {
        final result = review();

        expect(result.fsrs.state, isNot(FsrsState.newCard));
      });

      test('sets stability and difficulty to non-zero', () {
        final result = review();

        expect(result.fsrs.stability, greaterThan(0));
        expect(result.fsrs.difficulty, greaterThan(0));
      });

      test('schedules a next review date in the future', () {
        final before = DateTime.now().toUtc();
        final result = review();

        expect(result.fsrs.nextReviewAt, isNotNull);
        expect(
          result.fsrs.nextReviewAt!.isAfter(before),
          isTrue,
          reason: 'nextReviewAt should be scheduled after now',
        );
      });

      test('sets reps to 1', () {
        final result = review();

        expect(result.fsrs.reps, 1);
      });

      test('does not increment lapses on Rating.again for a new card', () {
        // Lapses only count when failing a card that was already in review.
        final result = review(rating: Rating.again);

        expect(result.fsrs.lapses, 0);
      });
    });

    group('subsequent reviews', () {
      FsrsCardData reviewOnce({Rating rating = Rating.good}) {
        return review(rating: rating).fsrs;
      }

      test('reps increments by 1 on each review', () {
        final first = reviewOnce();
        final second = scheduler
            .computeReview(
              itemId: 'item-1',
              itemType: ReviewableType.flashcard,
              currentFsrs: first,
              rating: Rating.good,
            )
            .fsrs;

        expect(first.reps, 1);
        expect(second.reps, 2);
      });

      test(
        'Rating.again in review state increments lapses',
        () {
          // Simulate a card that has already reached the review state.
          final inReview =
              const FsrsCardData(
                state: FsrsState.review,
                stability: 10,
                difficulty: 5,
                reps: 3,
                lapses: 0,
              ).copyWith(
                lastReviewAt: DateTime.now().toUtc().subtract(
                  const Duration(days: 5),
                ),
              );

          final result = review(current: inReview, rating: Rating.again);

          expect(result.fsrs.lapses, 1);
        },
      );

      test('Rating.good in review state does not increment lapses', () {
        final inReview =
            const FsrsCardData(
              state: FsrsState.review,
              stability: 10,
              difficulty: 5,
              reps: 3,
              lapses: 0,
            ).copyWith(
              lastReviewAt: DateTime.now().toUtc().subtract(
                const Duration(days: 5),
              ),
            );

        final result = review(current: inReview, rating: Rating.good);

        expect(result.fsrs.lapses, 0);
      });
    });

    group('rating influence on scheduling', () {
      test('Rating.easy schedules further out than Rating.good', () {
        final easy = review(rating: Rating.easy).fsrs;
        final good = review(rating: Rating.good).fsrs;

        expect(
          easy.nextReviewAt!.isAfter(good.nextReviewAt!),
          isTrue,
          reason: 'easy should schedule further in the future than good',
        );
      });

      test('Rating.good schedules further out than Rating.hard', () {
        final good = review(rating: Rating.good).fsrs;
        final hard = review(rating: Rating.hard).fsrs;

        expect(
          good.nextReviewAt!.isAfter(hard.nextReviewAt!) ||
              good.nextReviewAt!.isAtSameMomentAs(hard.nextReviewAt!),
          isTrue,
        );
      });
    });

    group('ReviewLog', () {
      test('captures the state and stats before the review', () {
        final before =
            const FsrsCardData(
              state: FsrsState.review,
              stability: 12.5,
              difficulty: 6.3,
              reps: 4,
            ).copyWith(
              lastReviewAt: DateTime.now().toUtc().subtract(
                const Duration(days: 3),
              ),
            );

        final result = review(current: before, rating: Rating.good);

        expect(result.log.stateBefore, FsrsState.review);
        expect(result.log.stabilityBefore, 12.5);
        expect(result.log.difficultyBefore, 6.3);
        expect(result.log.rating, Rating.good);
      });

      test('includes itemId and itemType', () {
        final result = review(
          itemId: 'highlight-42',
          itemType: ReviewableType.highlight,
        );

        expect(result.log.itemId, 'highlight-42');
        expect(result.log.itemType, ReviewableType.highlight);
      });

      test('passes reviewDurationMs through when provided', () {
        final result = review(durationMs: 4200);

        expect(result.log.reviewDurationMs, 4200);
      });

      test('leaves reviewDurationMs null when not provided', () {
        final result = review();

        expect(result.log.reviewDurationMs, isNull);
      });

      test('generates a unique id for each review log', () {
        final a = review().log.id;
        final b = review().log.id;

        expect(a, isNotEmpty);
        expect(a, isNot(b));
      });
    });
  });
}
