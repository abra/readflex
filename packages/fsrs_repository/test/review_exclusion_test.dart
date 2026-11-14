import 'dart:async';

import 'package:domain_models/domain_models.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs_repository/fsrs_repository.dart';
import 'package:local_storage/local_storage.dart';

void main() {
  late AppDatabase database;
  late FsrsRepository reviews;
  final now = DateTime.utc(2026, 11, 14, 12);

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    reviews = FsrsRepository(database: database, clock: () => now);
  });
  tearDown(() => database.close());

  Future<void> saveContent(
    String id, {
    ReviewableType type = ReviewableType.highlight,
  }) async {
    if (type == ReviewableType.dictionary) {
      await database.dictionaryDao.insertEntry(
        DictionaryTableCompanion.insert(
          id: id,
          word: id,
          translation: 'A saved meaning',
          addedAt: now.toIso8601String(),
        ),
      );
    } else {
      await database.highlightsDao.insertHighlight(
        HighlightsTableCompanion.insert(
          id: id,
          sourceId: 'book',
          sourceType: 'book',
          highlightText: 'A saved passage from $id',
          createdAt: now.toIso8601String(),
        ),
      );
    }
  }

  Future<void> track(
    String id, {
    ReviewableType type = ReviewableType.highlight,
    FsrsState state = FsrsState.newCard,
    DateTime? due,
  }) async {
    await saveContent(id, type: type);
    await database.reviewItemsDao.insertItem(
      ReviewItemsTableCompanion(
        itemId: Value(id),
        itemType: Value(type.toStorageString()),
        sourceId: const Value('book'),
        fsrsState: Value(state.toStorageString()),
        nextReviewAt: Value(due?.toIso8601String()),
      ),
    );
  }

  Future<FsrsCardData> rate(
    String id, {
    ReviewableType type = ReviewableType.highlight,
  }) => reviews.recordReview(
    itemId: id,
    itemType: type,
    sourceId: 'book',
    rating: Rating.good,
  );

  test(
    'excluded cards stay out of queues, deadlines, states and counts',
    () async {
      final future = now.add(const Duration(hours: 1));
      final mastered = now.add(const Duration(hours: 2));
      for (final excluded in [true, false]) {
        final prefix = excluded ? 'excluded' : 'active';
        await track('$prefix-new');
        await track(
          '$prefix-overdue',
          type: ReviewableType.dictionary,
          state: FsrsState.learning,
          due: now.subtract(const Duration(minutes: 1)),
        );
        await track(
          '$prefix-future',
          state: FsrsState.review,
          due: excluded ? now.add(const Duration(minutes: 1)) : future,
        );
        await track(
          '$prefix-mastered',
          type: ReviewableType.dictionary,
          state: FsrsState.review,
          due: excluded ? now.add(const Duration(minutes: 2)) : mastered,
        );
        if (excluded) {
          for (final suffix in ['new', 'overdue', 'future', 'mastered']) {
            await reviews.excludeReviewItem('$prefix-$suffix');
          }
        }
      }

      expect(
        (await reviews.getDueItems()).map((item) => item.itemId),
        ['active-new', 'active-overdue'],
      );
      expect(
        (await reviews.getDueItems(limit: 1)).single.itemId,
        'active-new',
      );
      expect(
        (await reviews.getDueItemsBySource('book')).map((item) => item.itemId),
        ['active-new', 'active-overdue'],
      );
      expect(await reviews.getDueItemCount(), 2);
      expect(
        await reviews.getDueItemCount(type: ReviewableType.highlight),
        1,
      );
      expect(
        await reviews.getReviewQueueStatus(),
        ReviewQueueStatus(dueCount: 2, nextReviewAt: future),
      );
      expect(
        await reviews.getReviewQueueStatus(types: {ReviewableType.highlight}),
        ReviewQueueStatus(dueCount: 1, nextReviewAt: future),
      );
      expect(
        await reviews.getReviewQueueStatus(types: {ReviewableType.dictionary}),
        ReviewQueueStatus(dueCount: 1, nextReviewAt: mastered),
      );
      expect(await reviews.getReviewState('excluded-new'), isNull);
      expect(
        (await reviews.getReviewStates([
          'active-new',
          'excluded-new',
          'active-future',
          'excluded-future',
        ])).keys,
        unorderedEquals(['active-new', 'active-future']),
      );
      expect(
        (await reviews.getReviewItems(ReviewableType.highlight)).map(
          (item) => item.itemId,
        ),
        unorderedEquals(['active-new', 'active-future']),
      );
      expect(
        await reviews.getMasteredItemIds(),
        {'active-future', 'active-mastered'},
      );
      expect(
        await reviews.getMasteredItemIds(type: ReviewableType.highlight),
        {'active-future'},
      );
      final stats = await reviews.getStats();
      expect(stats.due, 2);
      expect(stats.total, 4);
      expect(stats.masteredOf(ReviewableType.highlight), 1);
      expect(stats.masteredOf(ReviewableType.dictionary), 1);
      expect(stats.totalOf(ReviewableType.highlight), 2);
      expect(stats.totalOf(ReviewableType.dictionary), 2);
      expect(await database.reviewItemsDao.itemCount(), 4);
      expect(await database.reviewItemsDao.masteredItemCount(), 2);
    },
  );

  test('backfill and ensure keep excluded rows and their schedule', () async {
    await saveContent('legacy');
    await track('excluded');
    await rate('excluded');
    await reviews.excludeReviewItem('excluded');
    final excluded = await database.reviewItemsDao.byItemId('excluded');
    expect(excluded!.isExcluded, isTrue);

    await reviews.ensureReviewItems([
      const ReviewItem(
        itemId: 'excluded',
        itemType: ReviewableType.highlight,
        sourceId: 'book',
        fsrs: FsrsCardData(),
      ),
    ]);
    await reviews.backfillTextHighlights();
    await reviews.backfillTextHighlights();

    expect(await reviews.getReviewState('excluded'), isNull);
    expect(await database.reviewItemsDao.byItemId('excluded'), excluded);
    expect(await reviews.getReviewState('legacy'), const FsrsCardData());
    expect(await database.reviewItemsDao.reviewLogCount(), 1);
  });

  for (final type in [ReviewableType.dictionary, ReviewableType.highlight]) {
    test('a late $type rating cannot reactivate an excluded card', () async {
      await track('excluded', type: type);
      await rate('excluded', type: type);
      final contentBefore = type == ReviewableType.dictionary
          ? await database.dictionaryDao.entryById('excluded')
          : await database.highlightsDao.highlightById('excluded');
      await reviews.excludeReviewItem('excluded');
      final excluded = await database.reviewItemsDao.byItemId('excluded');

      await expectLater(
        rate('excluded', type: type),
        throwsA(isA<NotFoundException>()),
      );

      expect(await database.reviewItemsDao.byItemId('excluded'), excluded);
      expect(await reviews.getReviewState('excluded'), isNull);
      expect(
        type == ReviewableType.dictionary
            ? await database.dictionaryDao.entryById('excluded')
            : await database.highlightsDao.highlightById('excluded'),
        contentBefore,
      );
      final stats = await reviews.getStats();
      expect(stats.totalReviews, 1);
      expect(stats.reviewedToday, 1);
      expect(stats.total, 0);
    });
  }

  for (final exclusionFirst in [true, false]) {
    test(
      'overlapping rating/exclusion, exclusion first=$exclusionFirst',
      () async {
        await track('card');
        final firstEntered = Completer<void>();
        final release = Completer<void>();
        addTearDown(() {
          if (!release.isCompleted) release.complete();
        });
        final first = database.transaction(() async {
          if (exclusionFirst) {
            await reviews.excludeReviewItem('card');
          } else {
            await rate('card');
          }
          firstEntered.complete();
          await release.future;
        });
        await Future.any([firstEntered.future, first]);
        final second = exclusionFirst
            ? expectLater(rate('card'), throwsA(isA<NotFoundException>()))
            : reviews.excludeReviewItem('card');
        release.complete();
        await first;
        await second;

        expect(await reviews.getReviewState('card'), isNull);
        expect(
          (await database.reviewItemsDao.byItemId('card'))!.isExcluded,
          isTrue,
        );
        expect(
          await database.reviewItemsDao.reviewLogCount(),
          exclusionFirst ? 0 : 1,
        );
      },
    );
  }

  test(
    'exclusion is idempotent and a missing item creates no marker',
    () async {
      await reviews.excludeReviewItem('missing');
      expect(await database.reviewItemsDao.byItemId('missing'), isNull);
      await track('card');
      await rate('card');
      await reviews.excludeReviewItem('card');
      final excluded = await database.reviewItemsDao.byItemId('card');
      await reviews.excludeReviewItem('card');
      expect(await database.reviewItemsDao.byItemId('card'), excluded);

      await reviews.deleteReviewItem('card');
      expect(await database.reviewItemsDao.byItemId('card'), isNull);
      expect(await database.reviewItemsDao.reviewLogCount(), 1);
    },
  );

  test(
    'exclusion storage failures retain the repository exception type',
    () async {
      await database.customStatement('DROP TABLE review_items_table');
      await expectLater(
        reviews.excludeReviewItem('card'),
        throwsA(isA<StorageException>()),
      );
    },
  );
}
