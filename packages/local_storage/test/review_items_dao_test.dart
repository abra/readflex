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
