import 'package:collection_repository/collection_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_storage/local_storage.dart';

void main() {
  late AppDatabase db;
  late CollectionRepository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = CollectionRepository(database: db);
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'createCollectionWithSources stores collection and memberships',
    () async {
      final collection = await repository.createCollectionWithSources(
        name: 'Dune',
        sourceIds: const ['book-1', 'book-2'],
      );

      final collections = await repository.getCollections();

      expect(collection.name, 'Dune');
      expect(collection.sourceCount, 2);
      expect(collections.single.id, collection.id);
      expect(collections.single.sourceCount, 2);
    },
  );

  test('addSourcesToCollection is idempotent per source id', () async {
    final collection = await repository.createCollection('Articles');

    await repository.addSourcesToCollection(
      collectionId: collection.id,
      sourceIds: const ['article-1', 'article-1'],
    );

    final collections = await repository.getCollections();

    expect(collections.single.sourceCount, 1);
  });

  test('getCollectionSourceIds returns memberships by collection id', () async {
    final first = await repository.createCollectionWithSources(
      name: 'Dune',
      sourceIds: const ['book-1', 'article-1'],
    );
    final second = await repository.createCollectionWithSources(
      name: 'Essays',
      sourceIds: const ['article-2'],
    );

    final sourceIds = await repository.getCollectionSourceIds();

    expect(sourceIds[first.id], {'book-1', 'article-1'});
    expect(sourceIds[second.id], {'article-2'});
  });

  test('removeSourcesFromCollections deletes dangling memberships', () async {
    final collection = await repository.createCollectionWithSources(
      name: 'Mixed',
      sourceIds: const ['book-1', 'article-1'],
    );
    expect(collection.sourceCount, 2);

    await repository.removeSourcesFromCollections(const ['book-1']);

    final collections = await repository.getCollections();

    expect(collections.single.sourceCount, 1);
  });
  test('renameCollection updates collection name', () async {
    final collection = await repository.createCollection('Old name');

    await repository.renameCollection(
      collectionId: collection.id,
      name: 'New name',
    );

    final collections = await repository.getCollections();

    expect(collections.single.name, 'New name');
  });

  test('updateCollection renames and removes memberships together', () async {
    final collection = await repository.createCollectionWithSources(
      name: 'Old name',
      sourceIds: const ['book-1', 'article-1'],
    );

    await repository.updateCollection(
      collectionId: collection.id,
      name: 'New name',
      removedSourceIds: const ['book-1'],
    );

    final collections = await repository.getCollections();
    final sourceIds = await repository.getCollectionSourceIds();

    expect(collections.single.name, 'New name');
    expect(collections.single.sourceCount, 1);
    expect(sourceIds[collection.id], {'article-1'});
  });

  test('deleteCollection removes collection and memberships', () async {
    final collection = await repository.createCollectionWithSources(
      name: 'Dune',
      sourceIds: const ['book-1', 'article-1'],
    );

    await repository.deleteCollection(collection.id);

    expect(await repository.getCollections(), isEmpty);
    expect(await repository.getCollectionSourceIds(), isEmpty);
  });

  test(
    'removeSourcesFromCollection only edits the target collection',
    () async {
      final first = await repository.createCollectionWithSources(
        name: 'Dune',
        sourceIds: const ['book-1', 'article-1'],
      );
      final second = await repository.createCollectionWithSources(
        name: 'Essays',
        sourceIds: const ['book-1'],
      );

      await repository.removeSourcesFromCollection(
        collectionId: first.id,
        sourceIds: const ['book-1'],
      );

      final sourceIds = await repository.getCollectionSourceIds();

      expect(sourceIds[first.id], {'article-1'});
      expect(sourceIds[second.id], {'book-1'});
    },
  );
}
