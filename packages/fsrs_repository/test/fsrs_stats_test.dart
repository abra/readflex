import 'package:domain_models/domain_models.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs_repository/fsrs_repository.dart';
import 'package:local_storage/local_storage.dart';

void main() {
  late AppDatabase db;
  late DateTime now;
  late FsrsRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    now = DateTime(2026, 10, 26, 15);
    repo = FsrsRepository(database: db, clock: () => now);
  });

  tearDown(() => db.close());

  Future<void> track(String id, ReviewableType type, {String? sourceId}) =>
      repo.createReviewItem(itemId: id, itemType: type, sourceId: sourceId);

  group('ensureReviewItems', () {
    test('adds missing rows and keeps existing scheduling', () async {
      await track('w1', ReviewableType.dictionary);
      final reviewed = await repo.recordReview(
        itemId: 'w1',
        itemType: ReviewableType.dictionary,
        rating: Rating.good,
      );

      await repo.ensureReviewItems([
        const ReviewItem(
          itemId: 'w1',
          itemType: ReviewableType.dictionary,
          fsrs: FsrsCardData(),
        ),
        const ReviewItem(
          itemId: 'h1',
          itemType: ReviewableType.highlight,
          sourceId: 'book-1',
          fsrs: FsrsCardData(),
        ),
      ]);

      expect((await repo.getReviewState('w1'))!.reps, reviewed.reps);
      final added = await repo.getReviewItems(ReviewableType.highlight);
      expect(added.single.itemId, 'h1');
      expect(added.single.sourceId, 'book-1');
    });

    test('ignores an empty list', () async {
      await repo.ensureReviewItems(const []);
      expect(await repo.getDueItemCount(), 0);
    });
  });

  group('getStats', () {
    test('is empty without data', () async {
      final stats = await repo.getStats();

      expect(stats.due, 0);
      expect(stats.total, 0);
      expect(stats.reviewedToday, 0);
      expect(stats.reviewedLast7Days, 0);
      expect(stats.streakDays, 0);
      expect(stats.totalReviews, 0);
    });

    test('counts due, total and mastered per type', () async {
      await track('w1', ReviewableType.dictionary);
      await track('w2', ReviewableType.dictionary);
      await track('h1', ReviewableType.highlight);
      await repo.recordReview(
        itemId: 'w1',
        itemType: ReviewableType.dictionary,
        rating: Rating.good,
      );

      final stats = await repo.getStats();

      expect(stats.totalOf(ReviewableType.dictionary), 2);
      expect(stats.totalOf(ReviewableType.highlight), 1);
      expect(stats.dueOf(ReviewableType.dictionary), 1);
      expect(stats.dueOf(ReviewableType.highlight), 1);
      expect(stats.due, 2);
      expect(stats.masteredOf(ReviewableType.dictionary), 1);
      expect(stats.reviewedToday, 1);
      expect(stats.newReviewedToday, 1);
      expect(stats.reviewedLast7Days, 1);
      expect(stats.streakDays, 1);
    });

    test(
      'an item becomes due again once the clock passes its due date',
      () async {
        await track('w1', ReviewableType.dictionary);
        await repo.recordReview(
          itemId: 'w1',
          itemType: ReviewableType.dictionary,
          rating: Rating.good,
        );
        expect((await repo.getStats()).due, 0);

        now = now.add(const Duration(days: 400));
        expect((await repo.getStats()).due, 1);
      },
    );

    test('streak counts consecutive days and survives a quiet today', () async {
      await track('w1', ReviewableType.dictionary);
      final start = now;
      for (final daysAgo in [3, 2, 1]) {
        now = start.subtract(Duration(days: daysAgo));
        await repo.recordReview(
          itemId: 'w1',
          itemType: ReviewableType.dictionary,
          rating: Rating.again,
        );
      }
      now = start;

      final stats = await repo.getStats();

      expect(stats.reviewedToday, 0);
      expect(stats.newReviewedToday, 0);
      expect(stats.reviewedLast7Days, 3);
      expect(stats.streakDays, 3);
      expect(stats.totalReviews, 3);
    });

    test('streak breaks on a missed day', () async {
      await track('w1', ReviewableType.dictionary);
      final start = now;
      for (final daysAgo in [4, 3, 1, 0]) {
        now = start.subtract(Duration(days: daysAgo));
        await repo.recordReview(
          itemId: 'w1',
          itemType: ReviewableType.dictionary,
          rating: Rating.again,
        );
      }
      now = start;

      expect((await repo.getStats()).streakDays, 2);
    });
  });

  group('previewIntervals', () {
    test('delegates to the scheduler for every rating', () {
      final preview = repo.previewIntervals(const FsrsCardData());
      expect(preview.length, Rating.values.length);
    });
  });
}
