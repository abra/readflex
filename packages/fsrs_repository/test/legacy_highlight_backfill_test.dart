import 'package:domain_models/domain_models.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs_repository/fsrs_repository.dart';
import 'package:local_storage/local_storage.dart';

void main() {
  late AppDatabase db;
  late FsrsRepository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = FsrsRepository(database: db);
  });
  tearDown(() => db.close());

  Future<void> save(String id, {String kind = 'text'}) =>
      db.highlightsDao.insertHighlight(
        HighlightsTableCompanion.insert(
          id: id,
          sourceId: 'source-$id',
          sourceType: 'book',
          kind: Value(kind),
          highlightText: 'A passage from $id',
          createdAt: DateTime.utc(2026).toIso8601String(),
        ),
      );

  test('startup repair registers only missing text highlights', () async {
    await save('legacy');
    await save('tracked');
    await save('image', kind: 'imageArea');
    await repository.recordReview(
      itemId: 'tracked',
      itemType: ReviewableType.highlight,
      sourceId: 'source-tracked',
      rating: Rating.good,
    );
    final scheduled = await db.reviewItemsDao.byItemId('tracked');

    await repository.backfillTextHighlights();
    final legacy = (await repository.getDueItems()).single;
    expect(legacy.itemId, 'legacy');
    expect(legacy.itemType, ReviewableType.highlight);
    expect(legacy.sourceId, 'source-legacy');
    expect(legacy.fsrs, const FsrsCardData());
    expect(await repository.getReviewState('image'), isNull);
    expect(await db.reviewItemsDao.byItemId('tracked'), scheduled);
    expect(await db.reviewItemsDao.reviewLogCount(), 1);

    await repository.backfillTextHighlights();
    expect(await db.reviewItemsDao.itemCount(), 2);
    expect(await db.reviewItemsDao.byItemId('tracked'), scheduled);
    expect(await db.reviewItemsDao.reviewLogCount(), 1);
  });

  test('repair respects the global item ID key across legacy types', () async {
    await save('shared-id');
    await repository.createReviewItem(
      itemId: 'shared-id',
      itemType: ReviewableType.flashcard,
      sourceId: 'original-source',
    );
    final original = await db.reviewItemsDao.byItemId('shared-id');

    await repository.backfillTextHighlights();
    expect(await db.reviewItemsDao.byItemId('shared-id'), original);
    expect(await db.reviewItemsDao.itemCount(), 1);
  });

  test(
    'repair storage failures use the repository exception boundary',
    () async {
      await db.customStatement('DROP TABLE highlights_table');
      await expectLater(
        repository.backfillTextHighlights(),
        throwsA(isA<StorageException>()),
      );
    },
  );
}
