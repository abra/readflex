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
  Future<void> removeSourcesFromCollections(Iterable<String> sourceIds) async {}
}
