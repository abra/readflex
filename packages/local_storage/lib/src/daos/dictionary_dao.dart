import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/dictionary_anchors_table.dart';
import '../tables/dictionary_table.dart';

part 'dictionary_dao.g.dart';

/// CRUD access to dormant dictionary rows and their source anchors.
///
/// Kept for database compatibility while the Dictionary feature is outside the
/// active package graph.
@DriftAccessor(tables: [DictionaryTable, DictionaryAnchorsTable])
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

  Future<List<DictionaryAnchorsTableData>> anchorsBySource(String sourceId) =>
      (select(dictionaryAnchorsTable)
            ..where((t) => t.sourceId.equals(sourceId))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();

  Future<List<DictionaryAnchorsTableData>> anchorsByEntry(String entryId) =>
      (select(dictionaryAnchorsTable)
            ..where((t) => t.entryId.equals(entryId))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();

  Future<void> insertAnchor(DictionaryAnchorsTableCompanion anchor) =>
      into(dictionaryAnchorsTable).insert(anchor);

  Future<void> updateEntry(DictionaryTableCompanion entry) => (update(
    dictionaryTable,
  )..where((t) => t.id.equals(entry.id.value))).write(entry);

  Future<void> deleteEntry(String id) async {
    await deleteAnchorsByEntry(id);
    await (delete(dictionaryTable)..where((t) => t.id.equals(id))).go();
  }

  Future<void> deleteAnchorsByEntry(String entryId) => (delete(
    dictionaryAnchorsTable,
  )..where((t) => t.entryId.equals(entryId))).go();

  Future<void> deleteAnchorsBySource(String sourceId) => (delete(
    dictionaryAnchorsTable,
  )..where((t) => t.sourceId.equals(sourceId))).go();

  /// Bulk-removes every saved word that points at [sourceId]. Used when
  /// the parent source is deleted with the "delete everything" scope.
  Future<void> deleteEntriesBySource(String sourceId) async {
    await deleteAnchorsBySource(sourceId);
    await (delete(
      dictionaryTable,
    )..where((t) => t.sourceId.equals(sourceId))).go();
  }

  /// Detaches saved words from their source by nulling out [sourceId].
  /// Used by the "keep learning data" delete scope so the words survive
  /// the source deletion without dangling references to a now-missing row.
  Future<void> clearSourceForEntries(String sourceId) async {
    await deleteAnchorsBySource(sourceId);
    await (update(
      dictionaryTable,
    )..where((t) => t.sourceId.equals(sourceId))).write(
      const DictionaryTableCompanion(sourceId: Value(null)),
    );
  }
}
