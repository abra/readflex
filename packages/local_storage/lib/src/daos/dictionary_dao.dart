import 'package:drift/drift.dart';

import '../database.dart';
import '../dictionary_word_key.dart';
import '../tables/dictionary_anchors_table.dart';
import '../tables/dictionary_table.dart';

part 'dictionary_dao.g.dart';

/// CRUD access to saved words and their source anchors.
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

  /// Checks existence without reading the word's translations or context.
  Future<bool> entryExists(String id) async =>
      await (selectOnly(dictionaryTable)
            ..addColumns([dictionaryTable.id])
            ..where(dictionaryTable.id.equals(id)))
          .getSingleOrNull() !=
      null;

  /// The newest saved entry for [word] (case-insensitive), optionally only
  /// one saved from [sourceId].
  Future<DictionaryTableData?> entryByWord(String word, {String? sourceId}) =>
      (select(dictionaryTable)
            ..where((t) {
              final sameWord = t.wordKey.equals(dictionaryWordKey(word));
              if (sourceId == null) return sameWord;
              return sameWord & t.sourceId.equals(sourceId);
            })
            ..orderBy([(t) => OrderingTerm.desc(t.addedAt)])
            ..limit(1))
          .getSingleOrNull();

  Future<int> entryCount() {
    final count = dictionaryTable.id.count();
    return (selectOnly(
      dictionaryTable,
    )..addColumns([count])).map((row) => row.read(count) ?? 0).getSingle();
  }

  Future<List<DictionaryTableData>> entriesByIds(List<String> ids) =>
      (select(dictionaryTable)..where((t) => t.id.isIn(ids))).get();

  Future<void> insertEntry(DictionaryTableCompanion entry) =>
      into(dictionaryTable).insert(
        entry.copyWith(wordKey: Value(dictionaryWordKey(entry.word.value))),
      );

  Future<List<DictionaryAnchorsTableData>> anchorsBySource(String sourceId) =>
      (select(dictionaryAnchorsTable)
            ..where((t) => t.sourceId.equals(sourceId))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();

  Future<List<DictionaryAnchorsTableData>> anchorsByEntry(String entryId) =>
      (select(dictionaryAnchorsTable)
            ..where((t) => t.entryId.equals(entryId))
            ..orderBy([
              (t) => OrderingTerm.asc(t.createdAt),
              (t) => OrderingTerm.asc(t.rowId),
            ]))
          .get();

  /// Reads only the earliest anchor per entry, breaking timestamp ties by
  /// insertion order like [anchorsByEntry]. Chunks stay below SQLite's 999
  /// parameter baseline, including for large imported vocabularies.
  Future<List<DictionaryAnchorsTableData>> firstAnchorsByEntries(
    Iterable<String> entryIds,
  ) async {
    final ids = entryIds.toSet().toList();
    final result = <DictionaryAnchorsTableData>[];
    const batchSize = 500;
    for (var offset = 0; offset < ids.length; offset += batchSize) {
      final chunk = ids.skip(offset).take(batchSize).toList();
      final rows = await customSelect(
        '''
        WITH requested(entry_id) AS (VALUES ${List.filled(chunk.length, '(?)').join(', ')})
        SELECT anchor.* FROM requested
        JOIN dictionary_anchors_table AS anchor ON anchor.rowid = (
          SELECT candidate.rowid FROM dictionary_anchors_table AS candidate
          WHERE candidate.entry_id = requested.entry_id
          ORDER BY candidate.created_at ASC, candidate.rowid ASC
          LIMIT 1
        )
        ''',
        variables: [for (final id in chunk) Variable.withString(id)],
        readsFrom: {dictionaryAnchorsTable},
      ).get();
      result.addAll(rows.map((row) => dictionaryAnchorsTable.map(row.data)));
    }
    return result;
  }

  Future<void> insertAnchor(DictionaryAnchorsTableCompanion anchor) =>
      into(dictionaryAnchorsTable).insert(anchor);

  Future<void> updateEntry(DictionaryTableCompanion entry) =>
      (update(
        dictionaryTable,
      )..where((t) => t.id.equals(entry.id.value))).write(
        entry.word.present
            ? entry.copyWith(
                wordKey: Value(dictionaryWordKey(entry.word.value)),
              )
            : entry,
      );

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
