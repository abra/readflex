import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_storage/local_storage.dart';

void main() {
  late AppDatabase db;
  late DictionaryDao dao;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = db.dictionaryDao;
  });

  tearDown(() => db.close());

  DictionaryTableCompanion makeEntry({
    String id = 'e1',
    String word = 'hello',
    String translation = 'привет',
    String addedAt = '2026-01-01T00:00:00.000Z',
    String? sourceId,
  }) => DictionaryTableCompanion.insert(
    id: id,
    word: word,
    translation: translation,
    addedAt: addedAt,
    sourceId: Value(sourceId),
  );

  DictionaryAnchorsTableCompanion makeAnchor({
    String id = 'a1',
    String entryId = 'e1',
    String sourceId = 's1',
    String cfiRange = 'epubcfi(/6/4)',
  }) => DictionaryAnchorsTableCompanion.insert(
    id: id,
    entryId: entryId,
    sourceId: sourceId,
    sourceType: 'book',
    anchorText: 'hello',
    cfiRange: cfiRange,
    kind: 'exactSelection',
    createdAt: '2026-01-01T00:00:00.000Z',
  );

  test('insert and retrieve entry', () async {
    await dao.insertEntry(makeEntry());
    final entries = await dao.allEntries();
    expect(entries, hasLength(1));
    expect(entries.first.word, 'hello');
    expect(entries.first.translation, 'привет');
  });

  test('entriesBySource filters correctly', () async {
    await dao.insertEntry(makeEntry(id: 'e1', sourceId: 's1'));
    await dao.insertEntry(makeEntry(id: 'e2', sourceId: 's2'));
    final result = await dao.entriesBySource('s1');
    expect(result, hasLength(1));
    expect(result.first.id, 'e1');
  });

  test('entryCountBySource counts only source entries', () async {
    await dao.insertEntry(makeEntry(id: 'e1', sourceId: 's1'));
    await dao.insertEntry(makeEntry(id: 'e2', sourceId: 's1'));
    await dao.insertEntry(makeEntry(id: 'e3', sourceId: 's2'));
    await dao.insertEntry(makeEntry(id: 'e4'));

    expect(await dao.entryCountBySource('s1'), 2);
    expect(await dao.entryCountBySource('missing'), 0);
  });

  test('updateEntry modifies translation', () async {
    await dao.insertEntry(makeEntry());
    await dao.updateEntry(
      const DictionaryTableCompanion(
        id: Value('e1'),
        translation: Value('updated'),
      ),
    );
    final e = await dao.entryById('e1');
    expect(e!.translation, 'updated');
  });

  test('deleteEntry removes entry', () async {
    await dao.insertEntry(makeEntry());
    await dao.deleteEntry('e1');
    final entries = await dao.allEntries();
    expect(entries, isEmpty);
  });

  test('anchorsBySource filters dictionary anchors', () async {
    await dao.insertEntry(makeEntry(id: 'e1', sourceId: 's1'));
    await dao.insertEntry(makeEntry(id: 'e2', sourceId: 's2'));
    await dao.insertAnchor(makeAnchor(id: 'a1', entryId: 'e1', sourceId: 's1'));
    await dao.insertAnchor(makeAnchor(id: 'a2', entryId: 'e2', sourceId: 's2'));

    final anchors = await dao.anchorsBySource('s1');

    expect(anchors, hasLength(1));
    expect(anchors.single.id, 'a1');
  });

  test('deleteEntry removes anchors for entry', () async {
    await dao.insertEntry(makeEntry(id: 'e1', sourceId: 's1'));
    await dao.insertAnchor(makeAnchor(id: 'a1', entryId: 'e1', sourceId: 's1'));

    await dao.deleteEntry('e1');

    expect(await dao.anchorsByEntry('e1'), isEmpty);
  });

  test('clearSourceForEntries deletes anchors and detaches entries', () async {
    await dao.insertEntry(makeEntry(id: 'e1', sourceId: 's1'));
    await dao.insertAnchor(makeAnchor(id: 'a1', entryId: 'e1', sourceId: 's1'));

    await dao.clearSourceForEntries('s1');

    expect(await dao.anchorsBySource('s1'), isEmpty);
    expect((await dao.entryById('e1'))?.sourceId, isNull);
  });
}
