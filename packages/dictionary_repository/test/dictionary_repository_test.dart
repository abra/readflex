import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_storage/local_storage.dart';

void main() {
  late AppDatabase db;
  late DictionaryRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = DictionaryRepository(database: db);
  });

  tearDown(() => db.close());

  group('DictionaryRepository', () {
    test('addEntry creates and returns entry', () async {
      final e = await repo.addEntry(word: 'hello', translation: 'привет');
      expect(e.word, 'hello');
      expect(e.translation, 'привет');
      expect(e.id, isNotEmpty);
    });

    test('getEntries returns all entries', () async {
      await repo.addEntry(word: 'hello', translation: 'привет');
      await repo.addEntry(word: 'world', translation: 'мир');
      final entries = await repo.getEntries();
      expect(entries, hasLength(2));
    });

    test('getEntriesBySource filters correctly', () async {
      await repo.addEntry(
        word: 'book word',
        translation: 'перевод',
        sourceId: 's1',
        sourceType: SourceType.book,
      );
      await repo.addEntry(
        word: 'article word',
        translation: 'перевод',
        sourceId: 's2',
        sourceType: SourceType.book,
      );
      final result = await repo.getEntriesBySource('s1');
      expect(result, hasLength(1));
      expect(result.first.word, 'book word');
    });

    test('getEntryCountBySource returns source count', () async {
      await repo.addEntry(
        word: 'first',
        translation: 'первый',
        sourceId: 's1',
        sourceType: SourceType.book,
      );
      await repo.addEntry(
        word: 'second',
        translation: 'второй',
        sourceId: 's1',
        sourceType: SourceType.book,
      );
      await repo.addEntry(
        word: 'other',
        translation: 'другой',
        sourceId: 's2',
        sourceType: SourceType.book,
      );

      expect(await repo.getEntryCountBySource('s1'), 2);
      expect(await repo.getEntryCountBySource('missing'), 0);
    });

    test('getEntryById returns correct entry', () async {
      final created = await repo.addEntry(word: 'find', translation: 'найти');
      final found = await repo.getEntryById(created.id);
      expect(found, isNotNull);
      expect(found!.word, 'find');
    });

    test('getEntryById returns null for missing id', () async {
      final found = await repo.getEntryById('missing');
      expect(found, isNull);
    });

    test('updateEntry persists translation change', () async {
      final created = await repo.addEntry(word: 'test', translation: 'тест');
      final updated = created.copyWith(translation: 'испытание');
      await repo.updateEntry(updated);
      final fetched = await repo.getEntryById(created.id);
      expect(fetched!.translation, 'испытание');
    });

    test('deleteEntry removes entry', () async {
      final created = await repo.addEntry(
        word: 'remove',
        translation: 'удалить',
      );
      await repo.deleteEntry(created.id);
      final entries = await repo.getEntries();
      expect(entries, isEmpty);
    });

    test('deleteEntry also removes FSRS review row', () async {
      final created = await repo.addEntry(
        word: 'tracked',
        translation: 'отслеживаемый',
        sourceId: 's1',
        sourceType: SourceType.book,
      );
      await db.reviewItemsDao.upsertItem(
        ReviewItemsTableCompanion.insert(
          itemId: created.id,
          itemType: ReviewableType.dictionary.name,
          sourceId: const Value('s1'),
        ),
      );
      expect(await db.reviewItemsDao.byItemId(created.id), isNotNull);

      await repo.deleteEntry(created.id);

      expect(await db.reviewItemsDao.byItemId(created.id), isNull);
      expect(await repo.getEntries(), isEmpty);
    });

    test('usageExamples round-trips through storage', () async {
      final created = await repo.addEntry(
        word: 'example',
        translation: 'пример',
        usageExamples: ['This is an example.', 'Another example.'],
      );
      final fetched = await repo.getEntryById(created.id);
      expect(fetched!.usageExamples, hasLength(2));
      expect(fetched.usageExamples.first, 'This is an example.');
    });

    test('empty usageExamples round-trips as empty list', () async {
      final created = await repo.addEntry(word: 'empty', translation: 'пусто');
      final fetched = await repo.getEntryById(created.id);
      expect(fetched!.usageExamples, isEmpty);
    });
  });
}
