import 'package:bloc_test/bloc_test.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_feature/src/add_to_collection_cubit.dart';

import 'helpers/fake_collection_repository.dart';

void main() {
  late FakeCollectionRepository repository;

  setUp(() {
    repository = FakeCollectionRepository();
  });

  blocTest<AddToCollectionCubit, AddToCollectionState>(
    'load emits a typed failure when collections cannot be loaded',
    build: () {
      repository.shouldThrow = true;
      return AddToCollectionCubit(collectionRepository: repository);
    },
    act: (cubit) => cubit.load(),
    expect: () => [
      const AddToCollectionState(status: AddToCollectionStatus.loading),
      const AddToCollectionState(
        status: AddToCollectionStatus.failure,
        errorCode: AddToCollectionErrorCode.loadCollectionsFailed,
      ),
    ],
  );

  blocTest<AddToCollectionCubit, AddToCollectionState>(
    'addToCollection emits a typed failure when update fails',
    build: () {
      repository
        ..seedCollections([
          LibraryCollection(
            id: 'collection-1',
            name: 'Reading',
            sourceCount: 0,
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        ])
        ..shouldThrow = true;
      return AddToCollectionCubit(collectionRepository: repository);
    },
    act: (cubit) => cubit.addToCollection(
      collectionId: 'collection-1',
      sourceIds: const ['book-1'],
    ),
    expect: () => [
      const AddToCollectionState(status: AddToCollectionStatus.submitting),
      const AddToCollectionState(
        status: AddToCollectionStatus.failure,
        errorCode: AddToCollectionErrorCode.updateCollectionFailed,
      ),
    ],
  );
}
