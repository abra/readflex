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

  DictionaryTableCompanion _entry({
    String id = 'e1',
    String word = 'hello',
    String translation = 'привет',
    String addedAt = '2026-01-01T00:00:00.000Z',
    String? sourceId,
    String? nextReviewAt,
  }) => DictionaryTableCompanion.insert(
    id: id,
    word: word,
    translation: translation,
    addedAt: addedAt,
    sourceId: Value(sourceId),
    nextReviewAt: Value(nextReviewAt),
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

  test('dueEntries returns items with null or past nextReviewAt', () async {
    await dao.insertEntry(_entry(id: 'e1')); // null → due
    await dao.insertEntry(
      _entry(id: 'e2', nextReviewAt: '2026-01-01T00:00:00.000Z'),
    ); // past → due
    await dao.insertEntry(
      _entry(id: 'e3', nextReviewAt: '2099-01-01T00:00:00.000Z'),
    ); // future → not due
    final due = await dao.dueEntries('2026-06-01T00:00:00.000Z');
    expect(due, hasLength(2));
  });

  test('dueEntriesBySource filters by source and due date', () async {
    await dao.insertEntry(
      _entry(id: 'e1', sourceId: 's1'),
    ); // null → due, source s1
    await dao.insertEntry(
      _entry(
        id: 'e2',
        sourceId: 's1',
        nextReviewAt: '2099-01-01T00:00:00.000Z',
      ),
    ); // future → not due
    await dao.insertEntry(
      _entry(id: 'e3', sourceId: 's2'),
    ); // null → due, wrong source
    final due = await dao.dueEntriesBySource('s1', '2026-06-01T00:00:00.000Z');
    expect(due, hasLength(1));
    expect(due.first.id, 'e1');
  });

  test('insertReviewLog persists review log', () async {
    await dao.insertEntry(_entry());
    await dao.insertReviewLog(
      ReviewLogsTableCompanion.insert(
        id: 'r1',
        itemId: 'e1',
        itemType: 'dictionary',
        rating: 'good',
        stateBefore: 'new',
        stabilityBefore: 0.0,
        difficultyBefore: 0.0,
        retrievabilityAtReview: 0.0,
        scheduledDays: 1,
        elapsedDays: 0,
        reviewedAt: '2026-01-01T00:00:00.000Z',
      ),
    );
    final logs = await db.flashcardsDao.reviewLogsByItem('e1');
    expect(logs, hasLength(1));
    expect(logs.first.itemType, 'dictionary');
  });

  test('updateEntry modifies translation', () async {
    await dao.insertEntry(_entry());
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
    await dao.insertEntry(_entry());
    await dao.deleteEntry('e1');
    final entries = await dao.allEntries();
    expect(entries, isEmpty);
  });
}
