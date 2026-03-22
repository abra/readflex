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

  DictionaryEntriesTableCompanion _entry({
    String id = 'e1',
    String word = 'hello',
    String translation = 'привет',
    String addedAt = '2026-01-01T00:00:00.000Z',
    String? sourceId,
  }) => DictionaryEntriesTableCompanion.insert(
    id: id,
    word: word,
    translation: translation,
    addedAt: addedAt,
    sourceId: Value(sourceId),
  );

  test('insert and retrieve entry', () async {
    await dao.insertEntry(_entry());
    final entries = await dao.allEntries();
    expect(entries, hasLength(1));
    expect(entries.first.word, 'hello');
    expect(entries.first.translation, 'привет');
  });

  test('entriesBySource filters correctly', () async {
    await dao.insertEntry(_entry(id: 'e1', sourceId: 's1'));
    await dao.insertEntry(_entry(id: 'e2', sourceId: 's2'));
    final result = await dao.entriesBySource('s1');
    expect(result, hasLength(1));
    expect(result.first.id, 'e1');
  });

  test('updateEntry modifies translation', () async {
    await dao.insertEntry(_entry());
    await dao.updateEntry(
      const DictionaryEntriesTableCompanion(
        id: Value('e1'),
        translation: Value('updated'),
      ),
    );
    final e = await dao.entryById('e1');
    expect(e!.translation, 'updated');
  });

  test('deleteEntry removes entry', () async {
    await dao.insertEntry(_entry());
    await dao.deleteEntry('e1');
    final entries = await dao.allEntries();
    expect(entries, isEmpty);
  });
}
