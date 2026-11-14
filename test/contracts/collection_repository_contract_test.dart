import 'package:collection_repository/collection_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_storage/local_storage.dart';

import '../../packages/features/library/test/helpers/fake_collection_repository.dart';

void main() {
  for (final useFake in [false, true]) {
    group(useFake ? 'Library fake' : 'SQLite CollectionRepository', () {
      late CollectionRepository repository;

      setUp(() {
        if (useFake) {
          repository = FakeCollectionRepository();
        } else {
          final database = AppDatabase.forTesting(NativeDatabase.memory());
          addTearDown(database.close);
          repository = CollectionRepository(database: database);
        }
      });

      test(
        'membership writes deduplicate IDs and refresh source counts',
        () async {
          final collection = await repository.createCollectionWithSources(
            name: '  Reading  ',
            sourceIds: ['a', 'a'],
          );
          expect(collection.name, 'Reading');
          expect(collection.sourceCount, 1);
          await repository.addSourcesToCollection(
            collectionId: collection.id,
            sourceIds: ['a', 'b', 'b'],
          );
          expect((await repository.getCollections()).single.sourceCount, 2);
          await repository.updateCollection(
            collectionId: collection.id,
            name: '  Read next  ',
            removedSourceIds: ['a', 'a'],
          );
          final updated = (await repository.getCollections()).single;
          expect(updated.name, 'Read next');
          expect(updated.sourceCount, 1);
          expect(await repository.getCollectionSourceIds(), {
            collection.id: {'b'},
          });
        },
      );

      test('failed bulk add leaves every destination unchanged', () async {
        final collection = await repository.createCollectionWithSources(
          name: 'Reading',
          sourceIds: ['original'],
        );
        await expectLater(
          repository.addSourcesToCollections(
            collectionIds: [
              collection.id,
              CollectionRepository.favouritesCollectionId,
              'deleted-destination',
            ],
            sourceIds: ['new'],
          ),
          throwsA(isA<StorageException>()),
        );
        expect(await repository.getCollectionSourceIds(), {
          collection.id: {'original'},
        });
        expect(await repository.getFavouriteSourceIds(), isEmpty);
      });

      test('invalid rename cannot partially remove memberships', () async {
        final collection = await repository.createCollectionWithSources(
          name: 'Reading',
          sourceIds: ['a', 'b'],
        );
        await expectLater(
          repository.updateCollection(
            collectionId: collection.id,
            name: '   ',
            removedSourceIds: ['a'],
          ),
          throwsArgumentError,
        );
        expect((await repository.getCollections()).single.name, 'Reading');
        expect(await repository.getCollectionSourceIds(), {
          collection.id: {'a', 'b'},
        });
      });

      test(
        'Favourites stays out of manual collections and is protected',
        () async {
          const id = CollectionRepository.favouritesCollectionId;
          await repository.addSourcesToFavourites(sourceIds: ['a', 'a']);
          expect(await repository.getFavouriteSourceIds(), {'a'});
          expect(await repository.getCollections(), isEmpty);
          await expectLater(
            repository.deleteCollection(id),
            throwsArgumentError,
          );
          await expectLater(
            repository.renameCollection(collectionId: id, name: 'Changed'),
            throwsArgumentError,
          );
          expect(await repository.getFavouriteSourceIds(), {'a'});
        },
      );

      test('membership queries return independent snapshots', () async {
        final collection = await repository.createCollectionWithSources(
          name: 'Reading',
          sourceIds: ['a', 'b'],
        );
        final snapshot = await repository.getCollectionSourceIds();
        snapshot[collection.id]!.clear();
        expect(await repository.collectionsContainingAll(['a', 'b']), {
          collection.id,
        });
        expect(await repository.collectionsContainingAll([]), isEmpty);
        expect(
          await repository.collectionsContainingAll(['a', 'missing']),
          isEmpty,
        );
      });

      test(
        'deleting and creating collections never reuses a live identity',
        () async {
          final first = await repository.createCollection('First');
          final second = await repository.createCollection('Second');
          await repository.deleteCollection(first.id);
          final third = await repository.createCollection('Third');
          expect(third.id, isNot(second.id));
          expect(
            (await repository.getCollections()).map(
              (collection) => collection.id,
            ),
            unorderedEquals([second.id, third.id]),
          );
        },
      );

      test('source cleanup removes membership from every collection', () async {
        final collection = await repository.createCollectionWithSources(
          name: 'Reading',
          sourceIds: ['a', 'b'],
        );
        await repository.addSourcesToFavourites(sourceIds: ['a', 'b']);
        await repository.removeSourcesFromCollections(['a']);
        expect(await repository.getFavouriteSourceIds(), {'b'});
        expect(await repository.getCollectionSourceIds(), {
          collection.id: {'b'},
          CollectionRepository.favouritesCollectionId: {'b'},
        });
        await repository.deleteCollection(collection.id);
        expect(await repository.getCollections(), isEmpty);
        expect(await repository.getCollectionSourceIds(), {
          CollectionRepository.favouritesCollectionId: {'b'},
        });
      });
    });
  }
}
