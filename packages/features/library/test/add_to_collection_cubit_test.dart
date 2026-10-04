import 'dart:async';

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

  test('membership is refreshed after adding the selected sources', () async {
    final cubit = AddToCollectionCubit(collectionRepository: repository);
    addTearDown(cubit.close);
    await cubit.load(sourceIds: {'book-1', 'book-2'});
    expect(cubit.state.containingAll, isEmpty);
    await cubit.addToCollection(
      collectionId: 'reading',
      sourceIds: ['book-1', 'book-2'],
    );
    expect(cubit.state.containingAll, {'reading'});
    await cubit.addToFavourites(sourceIds: ['book-1', 'book-2']);
    expect(cubit.state.containingAll, contains('reading'));
    expect(cubit.state.containingAll, hasLength(2));
  });

  test(
    'closing a pending mutation avoids late emissions and snapshot reads',
    () async {
      final repository = _DelayedCollectionRepository();
      final cubit = AddToCollectionCubit(collectionRepository: repository);
      await cubit.load(sourceIds: {'book'});
      final pending = cubit.addToCollection(
        collectionId: 'reading',
        sourceIds: ['book'],
      );
      await cubit.addToCollection(collectionId: 'reading', sourceIds: ['book']);
      expect(repository.writes, 1);
      await cubit.close();
      repository.complete.complete();
      await pending;
      expect(repository.reads, 1);
      expect(repository.addedSourceIdsByCollection['reading'], {'book'});
    },
  );

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

class _DelayedCollectionRepository extends FakeCollectionRepository {
  final complete = Completer<void>();
  int writes = 0;
  int reads = 0;

  @override
  Future<List<LibraryCollection>> getCollections() {
    reads++;
    return super.getCollections();
  }

  @override
  Future<void> addSourcesToCollection({
    required String collectionId,
    required Iterable<String> sourceIds,
  }) async {
    writes++;
    await complete.future;
    await super.addSourcesToCollection(
      collectionId: collectionId,
      sourceIds: sourceIds,
    );
  }
}
