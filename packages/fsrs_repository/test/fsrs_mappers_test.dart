import 'package:domain_models/domain_models.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:local_storage/local_storage.dart';

import 'package:fsrs_repository/src/mappers/review_item_to_domain.dart';
import 'package:fsrs_repository/src/mappers/review_item_to_storage.dart';
import 'package:fsrs_repository/src/mappers/review_log_to_storage.dart';

void main() {
  final now = DateTime(2026, 4, 1);
  final later = DateTime(2026, 4, 10);

  group('ReviewItemToDomain', () {
    test('maps all fields including nested FsrsCardData', () {
      final row = ReviewItemsTableData(
        itemId: 'f1',
        itemType: 'flashcard',
        sourceId: 'book-1',
        fsrsState: 'review',
        stability: 5.5,
        difficulty: 3.2,
        retrievability: 0.9,
        reps: 4,
        lapses: 1,
        lastReviewAt: now.toIso8601String(),
        nextReviewAt: later.toIso8601String(),
        scheduledDays: 9,
        elapsedDays: 3,
      );

      final item = row.toDomainModel();

      expect(item.itemId, 'f1');
      expect(item.itemType, ReviewableType.flashcard);
      expect(item.sourceId, 'book-1');
      expect(item.fsrs.state, FsrsState.review);
      expect(item.fsrs.stability, 5.5);
      expect(item.fsrs.difficulty, 3.2);
      expect(item.fsrs.retrievability, 0.9);
      expect(item.fsrs.reps, 4);
      expect(item.fsrs.lapses, 1);
      expect(item.fsrs.lastReviewAt, now);
      expect(item.fsrs.nextReviewAt, later);
      expect(item.fsrs.scheduledDays, 9);
      expect(item.fsrs.elapsedDays, 3);
    });

    test('handles null optional fields', () {
      final row = ReviewItemsTableData(
        itemId: 'f2',
        itemType: 'highlight',
        sourceId: null,
        fsrsState: 'new',
        stability: 0.0,
        difficulty: 0.0,
        retrievability: 0.0,
        reps: 0,
        lapses: 0,
        lastReviewAt: null,
        nextReviewAt: null,
        scheduledDays: 0,
        elapsedDays: 0,
      );

      final item = row.toDomainModel();

      expect(item.sourceId, isNull);
      expect(item.fsrs.lastReviewAt, isNull);
      expect(item.fsrs.nextReviewAt, isNull);
      expect(item.fsrs.state, FsrsState.newCard);
    });
  });

  group('ReviewItemToStorage', () {
    test('flattens nested FsrsCardData to companion', () {
      final item = ReviewItem(
        itemId: 'f1',
        itemType: ReviewableType.flashcard,
        sourceId: 'book-1',
        fsrs: FsrsCardData(
          state: FsrsState.review,
          stability: 5.5,
          difficulty: 3.2,
          retrievability: 0.9,
          reps: 4,
          lapses: 1,
          lastReviewAt: now,
          nextReviewAt: later,
          scheduledDays: 9,
          elapsedDays: 3,
        ),
      );

      final companion = item.toStorageModel();

      expect(companion.itemId, const Value('f1'));
      expect(companion.itemType, const Value('flashcard'));
      expect(companion.sourceId, const Value('book-1'));
      expect(companion.fsrsState, const Value('review'));
      expect(companion.stability, const Value(5.5));
      expect(companion.difficulty, const Value(3.2));
      expect(companion.retrievability, const Value(0.9));
      expect(companion.reps, const Value(4));
      expect(companion.lapses, const Value(1));
      expect(companion.lastReviewAt, Value(now.toIso8601String()));
      expect(companion.nextReviewAt, Value(later.toIso8601String()));
      expect(companion.scheduledDays, const Value(9));
      expect(companion.elapsedDays, const Value(3));
    });

    test('round-trips through domain and back', () {
      final original = ReviewItem(
        itemId: 'f1',
        itemType: ReviewableType.flashcard,
        sourceId: 'book-1',
        fsrs: FsrsCardData(
          state: FsrsState.review,
          stability: 5.5,
          difficulty: 3.2,
          retrievability: 0.9,
          reps: 4,
          lapses: 1,
          lastReviewAt: now,
          nextReviewAt: later,
          scheduledDays: 9,
          elapsedDays: 3,
        ),
      );

      final companion = original.toStorageModel();
      final row = ReviewItemsTableData(
        itemId: companion.itemId.value,
        itemType: companion.itemType.value,
        sourceId: companion.sourceId.value,
        fsrsState: companion.fsrsState.value,
        stability: companion.stability.value,
        difficulty: companion.difficulty.value,
        retrievability: companion.retrievability.value,
        reps: companion.reps.value,
        lapses: companion.lapses.value,
        lastReviewAt: companion.lastReviewAt.value,
        nextReviewAt: companion.nextReviewAt.value,
        scheduledDays: companion.scheduledDays.value,
        elapsedDays: companion.elapsedDays.value,
      );
      final restored = row.toDomainModel();

      expect(restored, equals(original));
    });
  });

  group('ReviewLogToStorage', () {
    test('maps all fields to companion', () {
      final log = ReviewLog(
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
        reviewDurationMs: 4500,
        reviewedAt: now,
      );

      final companion = log.toStorageModel();

      expect(companion.id, const Value('log-1'));
      expect(companion.itemId, const Value('f1'));
      expect(companion.itemType, const Value('flashcard'));
      expect(companion.rating, const Value('good'));
      expect(companion.stateBefore, const Value('review'));
      expect(companion.stabilityBefore, const Value(5.0));
      expect(companion.difficultyBefore, const Value(3.0));
      expect(companion.retrievabilityAtReview, const Value(0.85));
      expect(companion.scheduledDays, const Value(7));
      expect(companion.elapsedDays, const Value(3));
      expect(companion.reviewDurationMs, const Value(4500));
      expect(companion.reviewedAt, Value(now.toIso8601String()));
    });

    test('handles null reviewDurationMs', () {
      final log = ReviewLog(
        id: 'log-2',
        itemId: 'f1',
        itemType: ReviewableType.highlight,
        rating: Rating.again,
        stateBefore: FsrsState.learning,
        stabilityBefore: 1.0,
        difficultyBefore: 5.0,
        retrievabilityAtReview: 0.3,
        scheduledDays: 1,
        elapsedDays: 0,
        reviewedAt: now,
      );

      final companion = log.toStorageModel();

      expect(companion.reviewDurationMs, const Value(null));
    });
  });
}
