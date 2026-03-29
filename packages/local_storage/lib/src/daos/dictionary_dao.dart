import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/dictionary_entries_table.dart';
import '../tables/review_logs_table.dart';

part 'dictionary_dao.g.dart';

@DriftAccessor(tables: [DictionaryEntriesTable, ReviewLogsTable])
class DictionaryDao extends DatabaseAccessor<AppDatabase>
    with _$DictionaryDaoMixin {
  DictionaryDao(super.db);

  Future<List<DictionaryEntriesTableData>> allEntries() => (select(
    dictionaryEntriesTable,
  )..orderBy([(t) => OrderingTerm.desc(t.addedAt)])).get();

  Future<List<DictionaryEntriesTableData>> entriesBySource(String sourceId) =>
      (select(dictionaryEntriesTable)
            ..where((t) => t.sourceId.equals(sourceId))
            ..orderBy([(t) => OrderingTerm.desc(t.addedAt)]))
          .get();

  Future<List<DictionaryEntriesTableData>> dueEntries(String now) =>
      (select(dictionaryEntriesTable)
            ..where(
              (t) =>
                  t.nextReviewAt.isNull() |
                  t.nextReviewAt.isSmallerOrEqual(Variable(now)),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.nextReviewAt)]))
          .get();

  Future<List<DictionaryEntriesTableData>> dueEntriesBySource(
    String sourceId,
    String now,
  ) =>
      (select(dictionaryEntriesTable)
            ..where(
              (t) =>
                  t.sourceId.equals(sourceId) &
                  (t.nextReviewAt.isNull() |
                      t.nextReviewAt.isSmallerOrEqual(Variable(now))),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.nextReviewAt)]))
          .get();

  Future<DictionaryEntriesTableData?> entryById(String id) => (select(
    dictionaryEntriesTable,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> insertEntry(DictionaryEntriesTableCompanion entry) =>
      into(dictionaryEntriesTable).insert(entry);

  Future<void> updateEntry(DictionaryEntriesTableCompanion entry) => (update(
    dictionaryEntriesTable,
  )..where((t) => t.id.equals(entry.id.value))).write(entry);

  Future<void> deleteEntry(String id) =>
      (delete(dictionaryEntriesTable)..where((t) => t.id.equals(id))).go();

  Future<void> insertReviewLog(ReviewLogsTableCompanion log) =>
      into(reviewLogsTable).insert(log);
}
