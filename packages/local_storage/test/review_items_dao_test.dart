import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_storage/local_storage.dart';

void main() {
  late AppDatabase db;
  late ReviewItemsDao dao;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = db.reviewItemsDao;
  });

  tearDown(() => db.close());

  ReviewItemsTableCompanion makeItem({
    String itemId = 'f1',
    String itemType = 'flashcard',
    String? sourceId = 'book-1',
    String fsrsState = 'new',
    String? nextReviewAt,
  }) => ReviewItemsTableCompanion(
    itemId: Value(itemId),
    itemType: Value(itemType),
    sourceId: Value(sourceId),
    fsrsState: Value(fsrsState),
    stability: const Value(0.0),
    difficulty: const Value(0.0),
    retrievability: const Value(0.0),
    reps: const Value(0),
    lapses: const Value(0),
    nextReviewAt: Value(nextReviewAt),
    scheduledDays: const Value(0),
    elapsedDays: const Value(0),
  );

  ReviewLogsTableCompanion makeLog({
    String id = 'log-1',
    String itemId = 'f1',
    String itemType = 'flashcard',
    String rating = 'good',
    String reviewedAt = '2026-04-01T00:00:00.000Z',
  }) => ReviewLogsTableCompanion(
    id: Value(id),
    itemId: Value(itemId),
    itemType: Value(itemType),
    rating: Value(rating),
    stateBefore: const Value('new'),
    stabilityBefore: const Value(0.0),
    difficultyBefore: const Value(0.0),
    retrievabilityAtReview: const Value(0.0),
    scheduledDays: const Value(0),
    elapsedDays: const Value(0),
    reviewedAt: Value(reviewedAt),
  );

  group('ReviewItemsDao', () {
    test('insertItem and byItemId returns inserted item', () async {
      await dao.insertItem(makeItem());
      final item = await dao.byItemId('f1');
      expect(item, isNotNull);
      expect(item!.itemType, 'flashcard');
      expect(item.sourceId, 'book-1');
    });

    test('byItemId returns null for missing id', () async {
      final item = await dao.byItemId('missing');
      expect(item, isNull);
    });

    test('byItemIds returns matching items', () async {
      await dao.insertItem(makeItem(itemId: 'f1'));
      await dao.insertItem(makeItem(itemId: 'f2'));
      await dao.insertItem(makeItem(itemId: 'f3'));

      final items = await dao.byItemIds(['f1', 'f3']);
      expect(items, hasLength(2));
    });

    test('byType returns items of specified type', () async {
      await dao.insertItem(makeItem(itemId: 'f1', itemType: 'flashcard'));
      await dao.insertItem(makeItem(itemId: 'h1', itemType: 'highlight'));

      final flashcards = await dao.byType('flashcard');
      expect(flashcards, hasLength(1));
      expect(flashcards.first.itemId, 'f1');
    });

    test('upsertItem updates existing item', () async {
      await dao.insertItem(makeItem(fsrsState: 'new'));
      await dao.upsertItem(makeItem(fsrsState: 'review'));

      final item = await dao.byItemId('f1');
      expect(item!.fsrsState, 'review');
    });

    test('deleteItem removes item', () async {
      await dao.insertItem(makeItem());
      await dao.deleteItem('f1');
      final item = await dao.byItemId('f1');
      expect(item, isNull);
    });
  });

  group('ReviewItemsDao due items', () {
    test('dueItems returns items with null nextReviewAt', () async {
      await dao.insertItem(makeItem(itemId: 'f1', nextReviewAt: null));
      final due = await dao.dueItems('2026-04-01T00:00:00.000Z');
      expect(due, hasLength(1));
    });

    test('dueItems returns items with past nextReviewAt', () async {
      await dao.insertItem(
        makeItem(
          itemId: 'f1',
          nextReviewAt: '2026-03-01T00:00:00.000Z',
        ),
      );
      final due = await dao.dueItems('2026-04-01T00:00:00.000Z');
      expect(due, hasLength(1));
    });

    test('dueItems excludes items with future nextReviewAt', () async {
      await dao.insertItem(
        makeItem(
          itemId: 'f1',
          nextReviewAt: '2026-05-01T00:00:00.000Z',
        ),
      );
      final due = await dao.dueItems('2026-04-01T00:00:00.000Z');
      expect(due, isEmpty);
    });

    test('dueItems filters by type', () async {
      await dao.insertItem(
        makeItem(itemId: 'f1', itemType: 'flashcard', nextReviewAt: null),
      );
      await dao.insertItem(
        makeItem(itemId: 'h1', itemType: 'highlight', nextReviewAt: null),
      );

      final flashcards = await dao.dueItems(
        '2026-04-01T00:00:00.000Z',
        type: 'flashcard',
      );
      expect(flashcards, hasLength(1));
      expect(flashcards.first.itemId, 'f1');
    });

    test('dueItemCount counts due items and filters by type', () async {
      await dao.insertItem(
        makeItem(itemId: 'f1', itemType: 'flashcard', nextReviewAt: null),
      );
      await dao.insertItem(
        makeItem(
          itemId: 'h1',
          itemType: 'highlight',
          nextReviewAt: '2026-03-01T00:00:00.000Z',
        ),
      );
      await dao.insertItem(
        makeItem(
          itemId: 'f2',
          itemType: 'flashcard',
          nextReviewAt: '2026-05-01T00:00:00.000Z',
        ),
      );

      expect(await dao.dueItemCount('2026-04-01T00:00:00.000Z'), 2);
      expect(
        await dao.dueItemCount(
          '2026-04-01T00:00:00.000Z',
          type: 'flashcard',
        ),
        1,
      );
    });

    test('dueItemsBySource filters by sourceId', () async {
      await dao.insertItem(
        makeItem(itemId: 'f1', sourceId: 'book-1', nextReviewAt: null),
      );
      await dao.insertItem(
        makeItem(itemId: 'f2', sourceId: 'book-2', nextReviewAt: null),
      );

      final due = await dao.dueItemsBySource(
        'book-1',
        '2026-04-01T00:00:00.000Z',
      );
      expect(due, hasLength(1));
      expect(due.first.itemId, 'f1');
    });
  });

  group('ReviewItemsDao exclusions', () {
    const now = '2026-11-04T07:00:00.000Z';
    const soon = '2026-11-04T07:05:00.000Z';
    const later = '2026-11-04T08:00:00.000Z';

    test(
      'exclusion keeps the complete row and survives registration',
      () async {
        final original = makeItem(
          itemId: 'highlight',
          itemType: 'highlight',
          fsrsState: 'review',
          nextReviewAt: later,
        );
        await dao.insertItem(original);
        final saved = (await dao.byItemId('highlight'))!;
        await dao.excludeItem('highlight');
        await dao.excludeItem('highlight');
        await dao.ensureItem(original);
        await dao.ensureItems([original]);

        final excluded = (await dao.byItemId('highlight'))!;
        expect(excluded, saved.copyWith(isExcluded: true));
        expect(await dao.byItemIds(['highlight']), [excluded]);
        expect(await dao.byType('highlight'), isEmpty);
        expect(await dao.itemCount(), 0);
        expect(await dao.itemCount(type: 'highlight'), 0);
        await dao.deleteItem('highlight');
        expect(await dao.byItemId('highlight'), isNull);
      },
    );

    test('excluding a missing item never creates tracking', () async {
      await dao.excludeItem('missing');
      expect(await dao.byItemId('missing'), isNull);
    });

    test('due filtering happens before type/source pagination', () async {
      for (final (id, type, source, due) in [
        ('excluded-new', 'highlight', 'book-1', null),
        ('excluded-due', 'highlight', 'book-1', '2026-11-03T07:00:00.000Z'),
        ('word', 'dictionary', 'book-1', null),
        ('other-source', 'highlight', 'book-2', null),
        ('active', 'highlight', 'book-1', now),
      ]) {
        await dao.insertItem(
          makeItem(
            itemId: id,
            itemType: type,
            sourceId: source,
            nextReviewAt: due,
          ),
        );
        if (id.startsWith('excluded')) await dao.excludeItem(id);
      }

      expect(
        (await dao.dueItemsBySource(
          'book-1',
          now,
          types: {'highlight'},
          states: {'new'},
          limit: 1,
        )).single.itemId,
        'active',
      );
      expect(
        (await dao.dueItems(now, type: 'highlight', limit: 1)).single.itemId,
        'other-source',
      );
      expect(await dao.dueItemCount(now), 3);
      expect(await dao.dueItemCount(now, type: 'highlight'), 2);
    });

    test(
      'excluded cards affect neither due counts nor future deadlines',
      () async {
        for (final (id, type, due) in [
          ('excluded-new', 'highlight', null),
          ('excluded-due', 'highlight', now),
          ('excluded-soon', 'highlight', soon),
          ('word', 'dictionary', null),
          ('word-later', 'dictionary', later),
        ]) {
          await dao.insertItem(
            makeItem(itemId: id, itemType: type, nextReviewAt: due),
          );
          if (id.startsWith('excluded')) await dao.excludeItem(id);
        }

        expect(await dao.reviewQueueStatus(now), (
          dueCount: 1,
          nextReviewAt: later,
        ));
        expect(
          await dao.reviewQueueStatus(now, types: {'highlight'}),
          (dueCount: 0, nextReviewAt: null),
        );
        await dao.excludeItem('word');
        await dao.excludeItem('word-later');
        expect(await dao.reviewQueueStatus(now), (
          dueCount: 0,
          nextReviewAt: null,
        ));
      },
    );

    test('mastered queries filter excluded rows before pagination', () async {
      for (final id in ['excluded', 'active']) {
        await dao.insertItem(
          makeItem(itemId: id, itemType: 'highlight', fsrsState: 'review'),
        );
      }
      await dao.excludeItem('excluded');
      expect((await dao.masteredItems(limit: 1)).single.itemId, 'active');
      expect(
        (await dao.masteredItems(type: 'highlight', limit: 1)).single.itemId,
        'active',
      );
      expect(await dao.masteredItemCount(), 1);
      expect(await dao.masteredItemCount(type: 'highlight'), 1);
    });

    test('hard source cleanup also removes excluded tracking', () async {
      for (final (id, source) in [('remove', 'book-1'), ('keep', 'book-2')]) {
        await dao.insertItem(makeItem(itemId: id, sourceId: source));
        await dao.excludeItem(id);
      }
      await dao.deleteItemsBySource('book-1');
      expect(await dao.byItemId('remove'), isNull);
      expect((await dao.byItemId('keep'))!.isExcluded, isTrue);
      await dao.deleteItemsByIds(['keep']);
      expect(await dao.byItemId('keep'), isNull);
    });
  });

  group('ReviewItemsDao queue status', () {
    const now = '2026-11-04T07:00:00.000Z';
    const soon = '2026-11-04T07:05:00.000Z';
    const later = '2026-11-04T08:00:00.000Z';

    test('an empty queue has no deadline', () async {
      expect(
        await dao.reviewQueueStatus(now),
        (dueCount: 0, nextReviewAt: null),
      );
    });

    test(
      'counts new, overdue and exact-time items, with next future time',
      () async {
        for (final (id, due) in [
          ('new', null),
          ('overdue', '2026-11-03T07:00:00.000Z'),
          ('now', now),
          ('later', later),
          ('soon', soon),
        ]) {
          await dao.insertItem(makeItem(itemId: id, nextReviewAt: due));
        }
        expect(
          await dao.reviewQueueStatus(now),
          (dueCount: 3, nextReviewAt: soon),
        );
        expect(
          await dao.reviewQueueStatus(soon),
          (dueCount: 4, nextReviewAt: later),
        );
        expect(
          await dao.reviewQueueStatus(later),
          (dueCount: 5, nextReviewAt: null),
        );
      },
    );

    test(
      'filters both due count and future deadline by active types',
      () async {
        for (final (id, type, due) in [
          ('word', 'dictionary', null),
          ('word-later', 'dictionary', later),
          ('highlight', 'highlight', now),
          ('highlight-soon', 'highlight', soon),
          ('legacy', 'flashcard', null),
          ('legacy-sooner', 'flashcard', '2026-11-04T07:01:00.000Z'),
        ]) {
          await dao.insertItem(
            makeItem(itemId: id, itemType: type, nextReviewAt: due),
          );
        }
        expect(
          await dao.reviewQueueStatus(now, types: {'dictionary', 'highlight'}),
          (dueCount: 2, nextReviewAt: soon),
        );
        expect(
          await dao.reviewQueueStatus(now, types: {'dictionary'}),
          (dueCount: 1, nextReviewAt: later),
        );
        expect(
          await dao.reviewQueueStatus(now),
          (dueCount: 3, nextReviewAt: '2026-11-04T07:01:00.000Z'),
        );
        expect(
          await dao.reviewQueueStatus(now, types: {}),
          (dueCount: 0, nextReviewAt: null),
        );
      },
    );

    test('type filters are bound values', () async {
      const unusualType = "dictionary') OR 1 = 1 --";
      await dao.insertItem(makeItem(itemId: 'ordinary'));
      await dao.insertItem(
        makeItem(itemId: 'unusual', itemType: unusualType, nextReviewAt: soon),
      );
      expect(
        await dao.reviewQueueStatus(now, types: {unusualType}),
        (dueCount: 0, nextReviewAt: soon),
      );
    });
  });

  group('ReviewItemsDao mastered items', () {
    test('masteredItems returns items in review state', () async {
      await dao.insertItem(makeItem(itemId: 'f1', fsrsState: 'review'));
      await dao.insertItem(makeItem(itemId: 'f2', fsrsState: 'learning'));

      final mastered = await dao.masteredItems();
      expect(mastered, hasLength(1));
      expect(mastered.first.itemId, 'f1');
    });

    test('masteredItems filters by type', () async {
      await dao.insertItem(
        makeItem(
          itemId: 'f1',
          itemType: 'flashcard',
          fsrsState: 'review',
        ),
      );
      await dao.insertItem(
        makeItem(
          itemId: 'h1',
          itemType: 'highlight',
          fsrsState: 'review',
        ),
      );

      final mastered = await dao.masteredItems(type: 'flashcard');
      expect(mastered, hasLength(1));
      expect(mastered.first.itemId, 'f1');
    });
  });

  group('ReviewItemsDao review logs', () {
    test('insertReviewLog and reviewLogsByItem returns logs', () async {
      await dao.insertItem(makeItem());
      await dao.insertReviewLog(makeLog());

      final logs = await dao.reviewLogsByItem('f1');
      expect(logs, hasLength(1));
      expect(logs.first.rating, 'good');
    });

    test('reviewLogsByItem returns empty for no logs', () async {
      final logs = await dao.reviewLogsByItem('f1');
      expect(logs, isEmpty);
    });

    test('reviewLogsByItem orders by reviewedAt desc', () async {
      await dao.insertItem(makeItem());
      await dao.insertReviewLog(
        makeLog(id: 'log-1', reviewedAt: '2026-04-01T00:00:00.000Z'),
      );
      await dao.insertReviewLog(
        makeLog(id: 'log-2', reviewedAt: '2026-04-02T00:00:00.000Z'),
      );

      final logs = await dao.reviewLogsByItem('f1');
      expect(logs.first.id, 'log-2');
    });
  });
}
