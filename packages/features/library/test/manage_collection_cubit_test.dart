import 'package:bloc_test/bloc_test.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_feature/src/manage_collection_cubit.dart';

import 'helpers/fake_collection_repository.dart';

void main() {
  late FakeCollectionRepository repository;

  setUp(() {
    repository = FakeCollectionRepository();
  });

  LibraryCollection collection() => LibraryCollection(
    id: 'collection-1',
    name: 'Dune',
    sourceCount: 2,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  blocTest<ManageCollectionCubit, ManageCollectionState>(
    'saveChanges updates manual collection name',
    build: () {
      repository.seedCollections([collection()]);
      return ManageCollectionCubit(collectionRepository: repository);
    },
    act: (cubit) => cubit.saveChanges(
      collectionId: 'collection-1',
      name: 'Dune Saga',
    ),
    expect: () => [
      const ManageCollectionState(status: ManageCollectionStatus.submitting),
      const ManageCollectionState(status: ManageCollectionStatus.success),
    ],
    verify: (_) async {
      final collections = await repository.getCollections();
      expect(collections.single.name, 'Dune Saga');
    },
  );

  blocTest<ManageCollectionCubit, ManageCollectionState>(
    'saveChanges removes sources from the target collection',
    build: () {
      repository.seedCollections([collection()]);
      repository.seedCollectionSourceIds({
        'collection-1': {'book-1', 'article-1'},
      });
      return ManageCollectionCubit(collectionRepository: repository);
    },
    act: (cubit) => cubit.saveChanges(
      collectionId: 'collection-1',
      removedSourceIds: ['book-1'],
    ),
    expect: () => [
      const ManageCollectionState(status: ManageCollectionStatus.submitting),
      const ManageCollectionState(status: ManageCollectionStatus.success),
    ],
    verify: (_) async {
      final sourceIds = await repository.getCollectionSourceIds();
      expect(sourceIds['collection-1'], {'article-1'});
    },
  );

  blocTest<ManageCollectionCubit, ManageCollectionState>(
    'deleteCollection removes manual collection',
    build: () {
      repository.seedCollections([collection()]);
      repository.seedCollectionSourceIds({
        'collection-1': {'book-1'},
      });
      return ManageCollectionCubit(collectionRepository: repository);
    },
    act: (cubit) => cubit.deleteCollection('collection-1'),
    expect: () => [
      const ManageCollectionState(status: ManageCollectionStatus.submitting),
      const ManageCollectionState(status: ManageCollectionStatus.success),
    ],
    verify: (_) async {
      expect(await repository.getCollections(), isEmpty);
      expect(await repository.getCollectionSourceIds(), isEmpty);
    },
  );
}
