import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 4, 1);

  ReviewLog log() => ReviewLog(
    id: 'log-1',
    itemId: 'f1',
    itemType: ReviewableType.flashcard,
    rating: Rating.good,
    stateBefore: FsrsState.review,
    stabilityBefore: 5.0,
    difficultyBefore: 3.0,
    retrievabilityAtReview: 0.85,
    scheduledDays: 7,
    elapsedDays: 3,
    reviewedAt: now,
    reviewDurationMs: 4500,
  );

  group('ReviewLog equality', () {
    test('same fields are equal', () {
      expect(log(), equals(log()));
    });

    test('different id are not equal', () {
      final other = ReviewLog(
        id: 'log-2',
        itemId: 'f1',
        itemType: ReviewableType.flashcard,
        rating: Rating.good,
        stateBefore: FsrsState.review,
        stabilityBefore: 5.0,
        difficultyBefore: 3.0,
        retrievabilityAtReview: 0.85,
        scheduledDays: 7,
        elapsedDays: 3,
        reviewedAt: now,
        reviewDurationMs: 4500,
      );
      expect(log(), isNot(equals(other)));
    });

    test('different rating are not equal', () {
      final other = ReviewLog(
        id: 'log-1',
        itemId: 'f1',
        itemType: ReviewableType.flashcard,
        rating: Rating.again,
        stateBefore: FsrsState.review,
        stabilityBefore: 5.0,
        difficultyBefore: 3.0,
        retrievabilityAtReview: 0.85,
        scheduledDays: 7,
        elapsedDays: 3,
        reviewedAt: now,
        reviewDurationMs: 4500,
      );
      expect(log(), isNot(equals(other)));
    });

    test('null reviewDurationMs', () {
      final noMs = ReviewLog(
        id: 'log-1',
        itemId: 'f1',
        itemType: ReviewableType.flashcard,
        rating: Rating.good,
        stateBefore: FsrsState.review,
        stabilityBefore: 5.0,
        difficultyBefore: 3.0,
        retrievabilityAtReview: 0.85,
        scheduledDays: 7,
        elapsedDays: 3,
        reviewedAt: now,
      );
      expect(noMs.reviewDurationMs, isNull);
    });
  });
}
