import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/dictionary_entries_table.dart';
import '../tables/review_logs_table.dart';

part 'dictionary_dao.g.dart';

@DriftAccessor(tables: [DictionaryTable, ReviewLogsTable])
class DictionaryDao extends DatabaseAccessor<AppDatabase>
    with _$DictionaryDaoMixin {
  DictionaryDao(super.db);

  Future<List<DictionaryTableData>> allEntries() => (select(
    dictionaryTable,
  )..orderBy([(t) => OrderingTerm.desc(t.addedAt)])).get();

  Future<List<DictionaryTableData>> entriesBySource(String sourceId) =>
      (select(dictionaryTable)
            ..where((t) => t.sourceId.equals(sourceId))
            ..orderBy([(t) => OrderingTerm.desc(t.addedAt)]))
          .get();

  Future<List<DictionaryTableData>> dueEntries(String now) =>
      (select(dictionaryTable)
            ..where(
              (t) =>
                  t.nextReviewAt.isNull() |
                  t.nextReviewAt.isSmallerOrEqual(Variable(now)),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.nextReviewAt)]))
          .get();

  Future<List<DictionaryTableData>> dueEntriesBySource(
    String sourceId,
    String now,
  ) =>
      (select(dictionaryTable)
            ..where(
              (t) =>
                  t.sourceId.equals(sourceId) &
                  (t.nextReviewAt.isNull() |
                      t.nextReviewAt.isSmallerOrEqual(Variable(now))),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.nextReviewAt)]))
          .get();

  Future<DictionaryTableData?> entryById(String id) => (select(
    dictionaryTable,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> insertEntry(DictionaryTableCompanion entry) =>
      into(dictionaryTable).insert(entry);

  Future<void> updateEntry(DictionaryTableCompanion entry) => (update(
    dictionaryTable,
  )..where((t) => t.id.equals(entry.id.value))).write(entry);

  Future<void> deleteEntry(String id) =>
      (delete(dictionaryTable)..where((t) => t.id.equals(id))).go();

  Future<void> insertReviewLog(ReviewLogsTableCompanion log) =>
      into(reviewLogsTable).insert(log);
}
