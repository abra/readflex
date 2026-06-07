import 'package:collection_repository/collection_repository.dart';
import 'package:domain_models/domain_models.dart';

class FakeCollectionRepository implements CollectionRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  final List<LibraryCollection> _collections = [];
  final Map<String, Set<String>> addedSourceIdsByCollection = {};
  bool shouldThrow = false;

  void seedCollections(List<LibraryCollection> collections) => _collections
    ..clear()
    ..addAll(collections);

  void seedCollectionSourceIds(Map<String, Set<String>> sourceIds) {
    addedSourceIdsByCollection
      ..clear()
      ..addAll(sourceIds.map((key, value) => MapEntry(key, value.toSet())));
  }

  @override
  Future<List<LibraryCollection>> getCollections() async {
    if (shouldThrow) throw StorageException(cause: 'fake error');
    return List.unmodifiable(_collections);
  }

  @override
  Future<LibraryCollection> createCollectionWithSources({
    required String name,
    required Iterable<String> sourceIds,
  }) async {
    if (shouldThrow) throw StorageException(cause: 'fake error');
    final collection = LibraryCollection(
      id: 'collection-${_collections.length + 1}',
      name: name.trim(),
      sourceCount: sourceIds.toSet().length,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    _collections.add(collection);
    addedSourceIdsByCollection[collection.id] = sourceIds.toSet();
    return collection;
  }

  @override
  Future<void> addSourcesToCollection({
    required String collectionId,
    required Iterable<String> sourceIds,
  }) async {
    if (shouldThrow) throw StorageException(cause: 'fake error');
    addedSourceIdsByCollection
        .putIfAbsent(collectionId, () => <String>{})
        .addAll(sourceIds);
  }

  @override
  Future<Map<String, Set<String>>> getCollectionSourceIds() async {
    if (shouldThrow) throw StorageException(cause: 'fake error');
    return addedSourceIdsByCollection.map(
      (key, value) => MapEntry(key, value.toSet()),
    );
  }

  @override
  Future<void> renameCollection({
    required String collectionId,
    required String name,
  }) async {
    if (shouldThrow) throw StorageException(cause: 'fake error');
    final index = _collections.indexWhere(
      (collection) => collection.id == collectionId,
    );
    if (index == -1) return;
    final collection = _collections[index];
    _collections[index] = LibraryCollection(
      id: collection.id,
      name: name.trim(),
      sourceCount: collection.sourceCount,
      createdAt: collection.createdAt,
      updatedAt: DateTime(2026, 1, 2),
    );
  }

  @override
  Future<void> deleteCollection(String collectionId) async {
    if (shouldThrow) throw StorageException(cause: 'fake error');
    _collections.removeWhere((collection) => collection.id == collectionId);
    addedSourceIdsByCollection.remove(collectionId);
  }

  @override
  Future<void> updateCollection({
    required String collectionId,
    String? name,
    Iterable<String> removedSourceIds = const [],
  }) async {
    if (shouldThrow) throw StorageException(cause: 'fake error');
    if (name != null) {
      await renameCollection(collectionId: collectionId, name: name);
    }
    await removeSourcesFromCollection(
      collectionId: collectionId,
      sourceIds: removedSourceIds,
    );
  }

  @override
  Future<void> removeSourcesFromCollection({
    required String collectionId,
    required Iterable<String> sourceIds,
  }) async {
    if (shouldThrow) throw StorageException(cause: 'fake error');
    addedSourceIdsByCollection[collectionId]?.removeAll(sourceIds.toSet());
  }

  @override
  Future<void> removeSourcesFromCollections(Iterable<String> sourceIds) async {
    final ids = sourceIds.toSet();
    for (final sourceIds in addedSourceIdsByCollection.values) {
      sourceIds.removeAll(ids);
    }
  }
}
