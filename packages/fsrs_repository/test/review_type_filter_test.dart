import 'package:domain_models/domain_models.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs_repository/fsrs_repository.dart';
import 'package:local_storage/local_storage.dart';

void main() {
  late AppDatabase db;
  late FsrsRepository repository;
  final now = DateTime.utc(2026, 11, 14, 12);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = FsrsRepository(database: db, clock: () => now);
    for (final (id, type, source, due) in [
      ('legacy', 'flashcard', 'book', null),
      ('highlight', 'highlight', 'book', null),
      ('word-1', 'dictionary', 'book', now.subtract(const Duration(days: 2))),
      (
        'other-word',
        'dictionary',
        'other',
        now.subtract(const Duration(days: 1)),
      ),
      ('word-2', 'dictionary', 'book', now),
      ('future', 'dictionary', 'book', now.add(const Duration(minutes: 1))),
    ]) {
      await db.reviewItemsDao.insertItem(
        ReviewItemsTableCompanion(
          itemId: Value(id),
          itemType: Value(type),
          sourceId: Value(source),
          nextReviewAt: Value(due?.toIso8601String()),
        ),
      );
    }
  });
  tearDown(() => db.close());

  test(
    'eligible types are filtered before global limits and offsets',
    () async {
      final first = await repository.getDueItems(
        types: {ReviewableType.dictionary},
        limit: 1,
      );
      expect(first.single.itemId, 'word-1');
      final next = await repository.getDueItems(
        types: {ReviewableType.dictionary},
        limit: 2,
        offset: 1,
      );
      expect(next.map((item) => item.itemId), ['other-word', 'word-2']);
    },
  );

  test(
    'eligible source items are filtered before limits and offsets',
    () async {
      final result = await repository.getDueItemsBySource(
        'book',
        types: {ReviewableType.dictionary},
        limit: 1,
        offset: 1,
      );
      expect(result.single.itemId, 'word-2');
    },
  );

  test('empty types include no items, null retains all stored types', () async {
    expect(await repository.getDueItems(types: {}), isEmpty);
    expect(await repository.getDueItemsBySource('book', types: {}), isEmpty);
    expect(await repository.getDueItems(), hasLength(5));
    expect(await repository.getDueItemsBySource('book'), hasLength(4));
  });

  test('state and type selection both happen before pagination', () async {
    await db.reviewItemsDao.updateItem(
      const ReviewItemsTableCompanion(
        itemId: Value('word-1'),
        fsrsState: Value('review'),
      ),
    );
    await db.reviewItemsDao.updateItem(
      const ReviewItemsTableCompanion(
        itemId: Value('word-2'),
        fsrsState: Value('learning'),
      ),
    );
    final first = await repository.getDueItems(
      types: {ReviewableType.dictionary},
      states: {FsrsState.learning, FsrsState.review, FsrsState.relearning},
      limit: 1,
    );
    expect(first.single.itemId, 'word-1');
    final next = await repository.getDueItemsBySource(
      'book',
      types: {ReviewableType.dictionary},
      states: {FsrsState.learning, FsrsState.review, FsrsState.relearning},
      limit: 1,
      offset: 1,
    );
    expect(next.single.itemId, 'word-2');
    final newCards = await repository.getDueItems(
      types: {ReviewableType.dictionary},
      states: {FsrsState.newCard},
    );
    expect(newCards.single.itemId, 'other-word');
    expect(await repository.getDueItems(states: {}), isEmpty);
    expect(await repository.getDueItemsBySource('book', states: {}), isEmpty);
  });

  test('singular and plural type filters cannot be combined', () async {
    await expectLater(
      repository.getDueItems(type: ReviewableType.dictionary, types: {}),
      throwsArgumentError,
    );
    await expectLater(
      repository.getDueItemsBySource(
        'book',
        type: ReviewableType.dictionary,
        types: {},
      ),
      throwsArgumentError,
    );
  });
}
