import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/collections_table.dart';

part 'collections_dao.g.dart';

/// CRUD access to manual collections and their source memberships.
///
/// CollectionRepository owns membership edits; source repositories delete
/// memberships in the same transaction as a source. Smart scopes use metadata.
@DriftAccessor(tables: [CollectionsTable, CollectionSourcesTable])
class CollectionsDao extends DatabaseAccessor<AppDatabase>
    with _$CollectionsDaoMixin {
  CollectionsDao(super.db);

  Future<List<QueryRow>> allCollectionsWithCounts() {
    return customSelect(
      '''
        SELECT c.id,
               c.name,
               c.created_at,
               c.updated_at,
               COUNT(cs.source_id) AS source_count
        FROM collections_table c
        LEFT JOIN collection_sources_table cs
          ON cs.collection_id = c.id
        GROUP BY c.id, c.name, c.created_at, c.updated_at
        ORDER BY c.updated_at DESC, c.name COLLATE NOCASE ASC
      ''',
      readsFrom: {collectionsTable, collectionSourcesTable},
    ).get();
  }

  Future<void> insertCollection(CollectionsTableCompanion collection) {
    return into(collectionsTable).insert(collection);
  }

  Future<void> insertCollectionIfAbsent(
    CollectionsTableCompanion collection,
  ) {
    return into(
      collectionsTable,
    ).insert(collection, mode: InsertMode.insertOrIgnore);
  }

  Future<int> renameCollection({
    required String collectionId,
    required String name,
    required String updatedAt,
  }) {
    return (update(
      collectionsTable,
    )..where((t) => t.id.equals(collectionId))).write(
      CollectionsTableCompanion(
        name: Value(name),
        updatedAt: Value(updatedAt),
      ),
    );
  }

  Future<int> deleteCollection(String collectionId) {
    return (delete(
      collectionsTable,
    )..where((t) => t.id.equals(collectionId))).go();
  }

  Future<int> deleteCollectionMemberships(String collectionId) {
    return (delete(
      collectionSourcesTable,
    )..where((t) => t.collectionId.equals(collectionId))).go();
  }

  Future<List<QueryRow>> allCollectionSourceIds() {
    return customSelect(
      '''
        SELECT collection_id,
               source_id
        FROM collection_sources_table
        ORDER BY collection_id ASC, source_id ASC
      ''',
      readsFrom: {collectionSourcesTable},
    ).get();
  }

  Future<List<String>> sourceIdsForCollection(String collectionId) {
    final t = collectionSourcesTable;
    final query = selectOnly(t)
      ..addColumns([t.sourceId])
      ..where(t.collectionId.equals(collectionId));
    return query.map((row) => row.read(t.sourceId)!).get();
  }

  /// Counts only the selected sources. Batches stay below SQLite's parameter
  /// limit and return one count per collection rather than all memberships.
  Future<Set<String>> collectionsContainingAll(
    Iterable<String> sourceIds,
  ) async {
    final ids = sourceIds.toSet().toList(growable: false);
    if (ids.isEmpty) return const {};
    final totals = <String, int>{};
    final t = collectionSourcesTable;
    final count = t.sourceId.count();
    for (var start = 0; start < ids.length; start += 500) {
      final query = selectOnly(t)
        ..addColumns([t.collectionId, count])
        ..where(t.sourceId.isIn(ids.skip(start).take(500)))
        ..groupBy([t.collectionId]);
      for (final row in await query.get()) {
        final id = row.read(t.collectionId)!;
        totals[id] = (totals[id] ?? 0) + row.read(count)!;
      }
    }
    return {
      for (final entry in totals.entries)
        if (entry.value == ids.length) entry.key,
    };
  }

  Future<void> addSources({
    required String collectionId,
    required Iterable<String> sourceIds,
    required String addedAt,
  }) {
    final companions = sourceIds.map(
      (sourceId) => CollectionSourcesTableCompanion.insert(
        collectionId: collectionId,
        sourceId: sourceId,
        addedAt: addedAt,
      ),
    );
    return batch((batch) {
      batch.insertAll(
        collectionSourcesTable,
        companions,
        mode: InsertMode.insertOrIgnore,
      );
    });
  }

  Future<void> removeSources({
    required String collectionId,
    required Iterable<String> sourceIds,
  }) {
    final ids = sourceIds.toSet();
    if (ids.isEmpty) return Future.value();
    return (delete(collectionSourcesTable)..where(
          (t) => t.collectionId.equals(collectionId) & t.sourceId.isIn(ids),
        ))
        .go();
  }

  Future<void> deleteSourceMemberships(Iterable<String> sourceIds) {
    final ids = sourceIds.toSet();
    if (ids.isEmpty) return Future.value();
    return (delete(
      collectionSourcesTable,
    )..where((t) => t.sourceId.isIn(ids))).go();
  }
}
