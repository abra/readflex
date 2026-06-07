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
}
