import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/highlights_table.dart';

part 'highlights_dao.g.dart';

/// CRUD access to [HighlightsTable] with by-source / by-ids filters and a
/// bulk by-source delete used when the parent book or article is removed.
/// Consumed by `HighlightRepository`, which wraps errors in
/// `StorageException`.
@DriftAccessor(tables: [HighlightsTable])
class HighlightsDao extends DatabaseAccessor<AppDatabase>
    with _$HighlightsDaoMixin {
  HighlightsDao(super.db);

  Future<List<HighlightsTableData>> allHighlights() => (select(
    highlightsTable,
  )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).get();

  Future<List<HighlightsTableData>> highlightsBySource(String sourceId) =>
      (select(highlightsTable)
            ..where((t) => t.sourceId.equals(sourceId))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  Future<HighlightsTableData?> highlightById(String id) => (select(
    highlightsTable,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<HighlightsTableData>> highlightsByIds(List<String> ids) =>
      (select(highlightsTable)..where((t) => t.id.isIn(ids))).get();

  Future<void> insertHighlight(HighlightsTableCompanion highlight) =>
      into(highlightsTable).insert(highlight);

  Future<void> updateHighlight(HighlightsTableCompanion highlight) => (update(
    highlightsTable,
  )..where((t) => t.id.equals(highlight.id.value))).write(highlight);

  Future<void> deleteHighlight(String id) =>
      (delete(highlightsTable)..where((t) => t.id.equals(id))).go();

  Future<void> deleteHighlightsBySource(String sourceId) =>
      (delete(highlightsTable)..where((t) => t.sourceId.equals(sourceId))).go();
}
