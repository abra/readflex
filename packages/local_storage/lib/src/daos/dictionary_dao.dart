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
}
