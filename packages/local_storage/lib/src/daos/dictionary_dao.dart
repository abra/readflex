import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/dictionary_table.dart';

part 'dictionary_dao.g.dart';

/// CRUD access to [DictionaryTable] with an extra by-source filter for the
/// reader's "words from this book" view. Consumed by
/// `DictionaryRepository`, which wraps errors in `StorageException`.
@DriftAccessor(tables: [DictionaryTable])
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

  Future<int> entryCountBySource(String sourceId) {
    final count = dictionaryTable.id.count();
    return (selectOnly(dictionaryTable)
          ..addColumns([count])
          ..where(dictionaryTable.sourceId.equals(sourceId)))
        .map((row) => row.read(count) ?? 0)
        .getSingle();
  }

  Future<DictionaryTableData?> entryById(String id) => (select(
    dictionaryTable,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<DictionaryTableData>> entriesByIds(List<String> ids) =>
      (select(dictionaryTable)..where((t) => t.id.isIn(ids))).get();

  Future<void> insertEntry(DictionaryTableCompanion entry) =>
      into(dictionaryTable).insert(entry);

  Future<void> updateEntry(DictionaryTableCompanion entry) => (update(
    dictionaryTable,
  )..where((t) => t.id.equals(entry.id.value))).write(entry);

  Future<void> deleteEntry(String id) =>
      (delete(dictionaryTable)..where((t) => t.id.equals(id))).go();

  /// Bulk-removes every saved word that points at [sourceId]. Used when
  /// the parent source is deleted with the "delete everything" scope.
  Future<void> deleteEntriesBySource(String sourceId) =>
      (delete(dictionaryTable)..where((t) => t.sourceId.equals(sourceId))).go();

  /// Detaches saved words from their source by nulling out [sourceId].
  /// Used by the "keep learning data" delete scope so the words survive
  /// the source deletion without dangling references to a now-missing row.
  Future<void> clearSourceForEntries(String sourceId) =>
      (update(
        dictionaryTable,
      )..where((t) => t.sourceId.equals(sourceId))).write(
        const DictionaryTableCompanion(sourceId: Value(null)),
      );
}
