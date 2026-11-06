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
    String createdAt = '2026-01-01T00:00:00.000Z',
  }) => DictionaryAnchorsTableCompanion.insert(
    id: id,
    entryId: entryId,
    sourceId: sourceId,
    sourceType: 'book',
    anchorText: 'hello',
    cfiRange: cfiRange,
    kind: 'exactSelection',
    createdAt: createdAt,
  );

  test('insert and retrieve entry', () async {
    await dao.insertEntry(makeEntry());
    final entries = await dao.allEntries();
    expect(entries, hasLength(1));
    expect(entries.first.word, 'hello');
    expect(entries.first.translation, 'привет');
  });

  for (final word in ['Слово', 'ÜBER', 'ΑΛΦΑ', 'Word']) {
    test('looks up $word with the same Unicode normalization', () async {
      await dao.insertEntry(makeEntry(word: ' $word '));
      for (final query in [word, word.toLowerCase(), word.toUpperCase()]) {
        expect((await dao.entryByWord(query))?.id, 'e1');
      }
    });
  }

  test('lookup keeps source scope and newest-entry ordering', () async {
    await dao.insertEntry(makeEntry(id: 'old', word: 'Слово', sourceId: 's1'));
    await dao.insertEntry(
      makeEntry(
        id: 'new',
        word: 'СЛОВО',
        sourceId: 's2',
        addedAt: '2026-02-01',
      ),
    );
    expect((await dao.entryByWord('слово'))?.id, 'new');
    expect((await dao.entryByWord('слово', sourceId: 's1'))?.id, 'old');
    expect(await dao.entryByWord('слово', sourceId: 'missing'), isNull);
  });

  test('renaming a word refreshes the key; other edits preserve it', () async {
    await dao.insertEntry(makeEntry(word: 'Слово'));
    await dao.updateEntry(
      const DictionaryTableCompanion(
        id: Value('e1'),
        word: Value('Другое'),
      ),
    );
    expect(await dao.entryByWord('слово'), isNull);
    expect((await dao.entryByWord('другое'))?.id, 'e1');
    await dao.updateEntry(
      const DictionaryTableCompanion(
        id: Value('e1'),
        translation: Value('changed'),
      ),
    );
    expect((await dao.entryByWord('ДРУГОЕ'))?.translation, 'changed');
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

  test('first anchors preserve oldest date and insertion-order ties', () async {
    await dao.insertEntry(makeEntry());
    await dao.insertEntry(makeEntry(id: 'e2'));
    await dao.insertAnchor(makeAnchor(id: 'newer', createdAt: '2026-02-01'));
    await dao.insertAnchor(makeAnchor(id: 'z-first'));
    await dao.insertAnchor(makeAnchor(id: 'a-second'));
    await dao.insertAnchor(makeAnchor(id: 'other', entryId: 'e2'));

    final result = await dao.firstAnchorsByEntries(['e1', 'missing', 'e1']);

    expect(result.map((row) => row.id), ['z-first']);
    expect(result.single.id, (await dao.anchorsByEntry('e1')).first.id);
    expect(await dao.firstAnchorsByEntries([]), isEmpty);
  });

  test(
    'first anchors handle more than 999 requested IDs in bounded batches',
    () async {
      final ids = List.generate(1201, (index) => 'entry-$index');
      for (final index in [0, 500, 1000, 1200]) {
        await dao.insertEntry(makeEntry(id: ids[index]));
        await dao.insertAnchor(
          makeAnchor(id: 'anchor-$index', entryId: ids[index]),
        );
      }
      final result = await dao.firstAnchorsByEntries(ids);
      expect(result.map((row) => row.entryId).toSet(), {
        ids[0],
        ids[500],
        ids[1000],
        ids[1200],
      });
    },
  );

  test('clearSourceForEntries deletes anchors and detaches entries', () async {
    await dao.insertEntry(makeEntry(id: 'e1', sourceId: 's1'));
    await dao.insertAnchor(makeAnchor(id: 'a1', entryId: 'e1', sourceId: 's1'));

    await dao.clearSourceForEntries('s1');

    expect(await dao.anchorsBySource('s1'), isEmpty);
    expect((await dao.entryById('e1'))?.sourceId, isNull);
  });
}
