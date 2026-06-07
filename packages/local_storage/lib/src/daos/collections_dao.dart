import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/collections_table.dart';

part 'collections_dao.g.dart';

/// CRUD access to manual collections and their source memberships.
///
/// Called only by `CollectionRepository`; smart collections do not touch this
/// DAO because they are derived from source metadata.
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

  Future<void> deleteSourceMemberships(Iterable<String> sourceIds) {
    final ids = sourceIds.toSet();
    if (ids.isEmpty) return Future.value();
    return (delete(
      collectionSourcesTable,
    )..where((t) => t.sourceId.isIn(ids))).go();
  }
}
