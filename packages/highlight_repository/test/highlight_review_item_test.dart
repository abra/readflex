import 'package:domain_models/domain_models.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:highlight_repository/highlight_repository.dart';
import 'package:local_storage/local_storage.dart';

void main() {
  late AppDatabase db;
  late HighlightRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = HighlightRepository(database: db);
  });

  tearDown(() => db.close());

  test('a new text highlight registers a due review row', () async {
    final h = await repo.addHighlight(
      sourceId: 'book-1',
      sourceType: SourceType.book,
      text: 'Quote',
      cfiRange: 'epubcfi(/6/4!/4/2,/1:0,/1:5)',
    );

    final row = await db.reviewItemsDao.byItemId(h.id);
    expect(row, isNotNull);
    expect(row!.itemType, ReviewableType.highlight.name);
    expect(row.sourceId, 'book-1');
  });

  test('recolouring the same range keeps its review history', () async {
    const cfi = 'epubcfi(/6/4!/4/2,/1:0,/1:5)';
    final first = await repo.addHighlight(
      sourceId: 'book-1',
      sourceType: SourceType.book,
      text: 'Quote',
      cfiRange: cfi,
    );
    await db.reviewItemsDao.updateItem(
      ReviewItemsTableCompanion(
        itemId: Value(first.id),
        reps: const Value(3),
      ),
    );

    final again = await repo.addHighlight(
      sourceId: 'book-1',
      sourceType: SourceType.book,
      text: 'Quote',
      cfiRange: cfi,
      color: HighlightColor.green,
      replaceHighlightIds: [first.id],
    );

    expect(again.id, first.id);
    expect((await db.reviewItemsDao.byItemId(first.id))!.reps, 3);
  });

  test('absorbed highlights lose their review rows', () async {
    final inner = await repo.addHighlight(
      sourceId: 'book-1',
      sourceType: SourceType.book,
      text: 'Quo',
      cfiRange: 'epubcfi(/6/4!/4/2,/1:0,/1:3)',
    );
    final outer = await repo.addHighlight(
      sourceId: 'book-1',
      sourceType: SourceType.book,
      text: 'Quote',
      cfiRange: 'epubcfi(/6/4!/4/2,/1:0,/1:5)',
      replaceHighlightIds: [inner.id],
    );

    expect(await db.reviewItemsDao.byItemId(inner.id), isNull);
    expect(await db.reviewItemsDao.byItemId(outer.id), isNotNull);
  });

  test('image-area highlights are not reviewable', () async {
    final h = await repo.addImageAreaHighlight(
      sourceId: 'comic-1',
      sourceType: SourceType.book,
      pageIndex: 1,
      x: 0,
      y: 0,
      width: 1,
      height: 1,
    );

    expect(await db.reviewItemsDao.byItemId(h.id), isNull);
  });
}
