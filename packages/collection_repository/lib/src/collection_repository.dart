import 'package:domain_models/domain_models.dart';
import 'package:drift/drift.dart' show QueryRow;
import 'package:local_storage/local_storage.dart';
import 'package:uuid/uuid.dart' show Uuid;

const _uuid = Uuid();

/// Repository for user-created library collections.
///
/// Smart collections (author, site/domain, etc.) are computed from source
/// metadata by the Library feature. This repository persists only manual
/// collections and their source memberships.
class CollectionRepository {
  CollectionRepository({required AppDatabase database})
    : _db = database,
      _dao = database.collectionsDao;

  final AppDatabase _db;
  final CollectionsDao _dao;

  Future<List<LibraryCollection>> getCollections() async {
    try {
      final rows = await _dao.allCollectionsWithCounts();
      return rows.map(_collectionFromRow).toList(growable: false);
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  Future<LibraryCollection> createCollection(String name) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Collection name is empty');
    }

    try {
      final now = DateTime.now();
      final collection = LibraryCollection(
        id: _uuid.v4(),
        name: normalizedName,
        sourceCount: 0,
        createdAt: now,
        updatedAt: now,
      );
      await _dao.insertCollection(
        CollectionsTableCompanion.insert(
          id: collection.id,
          name: collection.name,
          createdAt: collection.createdAt.toIso8601String(),
          updatedAt: collection.updatedAt.toIso8601String(),
        ),
      );
      return collection;
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  Future<void> addSourcesToCollection({
    required String collectionId,
    required Iterable<String> sourceIds,
  }) async {
    final ids = sourceIds.toSet();
    if (ids.isEmpty) return;

    try {
      final now = DateTime.now().toIso8601String();
      await _dao.addSources(
        collectionId: collectionId,
        sourceIds: ids,
        addedAt: now,
      );
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  Future<LibraryCollection> createCollectionWithSources({
    required String name,
    required Iterable<String> sourceIds,
  }) async {
    final ids = sourceIds.toSet();
    try {
      return await _db.transaction(() async {
        final collection = await createCollection(name);
        await addSourcesToCollection(
          collectionId: collection.id,
          sourceIds: ids,
        );
        return LibraryCollection(
          id: collection.id,
          name: collection.name,
          sourceCount: ids.length,
          createdAt: collection.createdAt,
          updatedAt: collection.updatedAt,
        );
      });
    } catch (e, st) {
      if (e is StorageException || e is ArgumentError) rethrow;
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  /// Removes dangling collection memberships when a source is deleted.
  Future<void> removeSourcesFromCollections(Iterable<String> sourceIds) async {
    final ids = sourceIds.toSet();
    if (ids.isEmpty) return;

    try {
      await _dao.deleteSourceMemberships(ids);
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  LibraryCollection _collectionFromRow(QueryRow row) {
    return LibraryCollection(
      id: row.read<String>('id'),
      name: row.read<String>('name'),
      sourceCount: row.read<int>('source_count'),
      createdAt: DateTime.parse(row.read<String>('created_at')),
      updatedAt: DateTime.parse(row.read<String>('updated_at')),
    );
  }
}
