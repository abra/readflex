import 'package:domain_models/domain_models.dart';
import 'package:drift/native.dart';
import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_storage/local_storage.dart';

void main() {
  late AppDatabase db;
  late DictionaryRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = DictionaryRepository(database: db);
  });

  tearDown(() async {
    await repo.dispose();
    await db.close();
  });

  group('review tracking', () {
    test('addEntry registers a due review row with the source', () async {
      final entry = await repo.addEntry(
        word: 'serendipity',
        translation: 'счастливая случайность',
        sourceId: 'book-1',
        sourceType: SourceType.book,
      );

      final row = await db.reviewItemsDao.byItemId(entry.id);
      expect(row, isNotNull);
      expect(row!.itemType, ReviewableType.dictionary.name);
      expect(row.sourceId, 'book-1');
      expect(row.nextReviewAt, isNull);
    });

    test('deleteEntry removes the review row', () async {
      final entry = await repo.addEntry(word: 'a', translation: 'б');
      await repo.deleteEntry(entry.id);

      expect(await db.reviewItemsDao.byItemId(entry.id), isNull);
    });
  });

  group('findEntry', () {
    test('matches case-insensitively and prefers the newest', () async {
      await repo.addEntry(
        word: 'Light',
        translation: 'свет',
        addedAt: DateTime(2026, 1, 1),
      );
      final newer = await repo.addEntry(
        word: 'light',
        translation: 'лёгкий',
        addedAt: DateTime(2026, 2, 1),
      );

      final found = await repo.findEntry('LIGHT');
      expect(found?.id, newer.id);
    });

    test('scopes to a source when asked', () async {
      await repo.addEntry(word: 'light', translation: 'свет', sourceId: 'b1');

      expect(await repo.findEntry('light', sourceId: 'b1'), isNotNull);
      expect(await repo.findEntry('light', sourceId: 'b2'), isNull);
      expect(await repo.findEntry(' light ', sourceId: 'b1'), isNotNull);
    });

    test('returns null for an unknown word', () async {
      expect(await repo.findEntry('nothing'), isNull);
    });
  });

  test('getEntryCount counts every saved word', () async {
    expect(await repo.getEntryCount(), 0);
    await repo.addEntry(word: 'a', translation: 'б');
    await repo.addEntry(word: 'c', translation: 'д');
    expect(await repo.getEntryCount(), 2);
  });
}
