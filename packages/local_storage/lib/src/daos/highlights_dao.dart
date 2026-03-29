import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/highlights_table.dart';
import '../tables/review_logs_table.dart';

part 'highlights_dao.g.dart';

@DriftAccessor(tables: [HighlightsTable, ReviewLogsTable])
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

  Future<List<HighlightsTableData>> dueHighlights(String now) =>
      (select(highlightsTable)
            ..where(
              (t) =>
                  t.nextReviewAt.isNull() |
                  t.nextReviewAt.isSmallerOrEqual(Variable(now)),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.nextReviewAt)]))
          .get();

  Future<List<HighlightsTableData>> dueHighlightsBySource(
    String sourceId,
    String now,
  ) =>
      (select(highlightsTable)
            ..where(
              (t) =>
                  t.sourceId.equals(sourceId) &
                  (t.nextReviewAt.isNull() |
                      t.nextReviewAt.isSmallerOrEqual(Variable(now))),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.nextReviewAt)]))
          .get();

  Future<HighlightsTableData?> highlightById(String id) => (select(
    highlightsTable,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> insertHighlight(HighlightsTableCompanion highlight) =>
      into(highlightsTable).insert(highlight);

  Future<void> updateHighlight(HighlightsTableCompanion highlight) => (update(
    highlightsTable,
  )..where((t) => t.id.equals(highlight.id.value))).write(highlight);

  Future<void> deleteHighlight(String id) =>
      (delete(highlightsTable)..where((t) => t.id.equals(id))).go();

  Future<void> deleteHighlightsBySource(String sourceId) =>
      (delete(highlightsTable)..where((t) => t.sourceId.equals(sourceId))).go();

  Future<void> insertReviewLog(ReviewLogsTableCompanion log) =>
      into(reviewLogsTable).insert(log);
}
