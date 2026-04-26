import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/review_items_table.dart';
import '../tables/review_logs_table.dart';

part 'review_items_dao.g.dart';

/// CRUD + due-queue queries over [ReviewItemsTable] and append-only writes
/// to [ReviewLogsTable]. Backs `FsrsRepository`, which wraps errors in
/// `StorageException`. Hot paths ([dueItems], [dueItemsBySource]) are
/// served by composite indexes created in `AppDatabase._createIndexes`.
@DriftAccessor(tables: [ReviewItemsTable, ReviewLogsTable])
class ReviewItemsDao extends DatabaseAccessor<AppDatabase>
    with _$ReviewItemsDaoMixin {
  ReviewItemsDao(super.db);

  // ─── Review items ───

  Future<ReviewItemsTableData?> byItemId(String itemId) => (select(
    reviewItemsTable,
  )..where((t) => t.itemId.equals(itemId))).getSingleOrNull();

  Future<List<ReviewItemsTableData>> byItemIds(List<String> itemIds) =>
      (select(reviewItemsTable)..where((t) => t.itemId.isIn(itemIds))).get();

  Future<List<ReviewItemsTableData>> byType(String itemType) => (select(
    reviewItemsTable,
  )..where((t) => t.itemType.equals(itemType))).get();

  /// Items that are due for review: never reviewed (nextReviewAt IS NULL)
  /// or nextReviewAt <= now.
  Future<List<ReviewItemsTableData>> dueItems(
    String now, {
    String? type,
    int? limit,
    int? offset,
  }) {
    final query = select(reviewItemsTable)
      ..where((t) {
        final dueCondition =
            t.nextReviewAt.isNull() |
            t.nextReviewAt.isSmallerOrEqual(Variable(now));
        if (type != null) {
          return t.itemType.equals(type) & dueCondition;
        }
        return dueCondition;
      })
      ..orderBy([(t) => OrderingTerm.asc(t.nextReviewAt)]);
    if (limit != null) query.limit(limit, offset: offset);
    return query.get();
  }

  Future<List<ReviewItemsTableData>> dueItemsBySource(
    String sourceId,
    String now, {
    String? type,
    int? limit,
    int? offset,
  }) {
    final query = select(reviewItemsTable)
      ..where((t) {
        final dueCondition =
            t.sourceId.equals(sourceId) &
            (t.nextReviewAt.isNull() |
                t.nextReviewAt.isSmallerOrEqual(Variable(now)));
        if (type != null) {
          return t.itemType.equals(type) & dueCondition;
        }
        return dueCondition;
      })
      ..orderBy([(t) => OrderingTerm.asc(t.nextReviewAt)]);
    if (limit != null) query.limit(limit, offset: offset);
    return query.get();
  }

  /// Items in 'review' state (mastered).
  Future<List<ReviewItemsTableData>> masteredItems({
    String? type,
    int? limit,
    int? offset,
  }) {
    final query = select(reviewItemsTable)
      ..where((t) {
        final mastered = t.fsrsState.equals('review');
        if (type != null) {
          return t.itemType.equals(type) & mastered;
        }
        return mastered;
      });
    if (limit != null) query.limit(limit, offset: offset);
    return query.get();
  }

  Future<void> insertItem(ReviewItemsTableCompanion item) =>
      into(reviewItemsTable).insert(item);

  Future<void> upsertItem(ReviewItemsTableCompanion item) =>
      into(reviewItemsTable).insertOnConflictUpdate(item);

  Future<void> updateItem(ReviewItemsTableCompanion item) => (update(
    reviewItemsTable,
  )..where((t) => t.itemId.equals(item.itemId.value))).write(item);

  Future<void> deleteItem(String itemId) =>
      (delete(reviewItemsTable)..where((t) => t.itemId.equals(itemId))).go();

  /// Bulk-removes review items by their source. Used when a book or
  /// article is deleted so its highlight/flashcard FSRS state doesn't
  /// linger in `dueItems()` queries.
  Future<void> deleteItemsBySource(String sourceId) => (delete(
    reviewItemsTable,
  )..where((t) => t.sourceId.equals(sourceId))).go();

  /// Bulk-removes review items by the underlying item ids — used when a
  /// single highlight/flashcard/dictionary entry is deleted in isolation.
  Future<void> deleteItemsByIds(List<String> itemIds) {
    if (itemIds.isEmpty) return Future.value();
    return (delete(
      reviewItemsTable,
    )..where((t) => t.itemId.isIn(itemIds))).go();
  }

  // ─── Review logs ───

  Future<void> insertReviewLog(ReviewLogsTableCompanion log) =>
      into(reviewLogsTable).insert(log);

  Future<List<ReviewLogsTableData>> reviewLogsByItem(String itemId) =>
      (select(reviewLogsTable)
            ..where((t) => t.itemId.equals(itemId))
            ..orderBy([(t) => OrderingTerm.desc(t.reviewedAt)]))
          .get();
}
