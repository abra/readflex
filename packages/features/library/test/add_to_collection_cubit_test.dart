import 'dart:async';

import 'package:collection_repository/collection_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_feature/src/add_to_collection_cubit.dart';

import 'helpers/fake_collection_repository.dart';

void main() {
  group('multiple destinations', () {
    late _RecordingCollectionRepository repository;
    late AddToCollectionCubit cubit;

    setUp(() {
      repository = _RecordingCollectionRepository()
        ..seedCollections([
          _collection('reading', 'Reading'),
          _collection('research', 'Research'),
        ]);
      cubit = AddToCollectionCubit(collectionRepository: repository);
      addTearDown(cubit.close);
    });

    test('selecting destinations only changes the pending draft', () async {
      await cubit.load(sourceIds: {'book'});
      cubit
        ..toggleCollection('reading')
        ..toggleCollection(CollectionRepository.favouritesCollectionId);

      expect(cubit.state.selectedDestinationCount, 2);
      expect(cubit.state.canSubmit, isTrue);
      expect(repository.batchWrites, 0);
      expect(repository.addedSourceIdsByCollection, isEmpty);

      cubit.toggleCollection('reading');
      expect(cubit.state.selectedCollectionIds, {
        CollectionRepository.favouritesCollectionId,
      });
    });

    test(
      'already included and unknown destinations cannot be selected',
      () async {
        repository.seedCollectionSourceIds({
          'reading': {'book'},
          'research': {'another-book'},
        });
        await cubit.load(sourceIds: {'book'});
        cubit
          ..toggleCollection('reading')
          ..toggleCollection('missing');

        expect(cubit.state.containingAll, {'reading'});
        expect(cubit.state.selectedCollectionIds, isEmpty);
        expect(cubit.state.canSubmit, isFalse);
      },
    );

    test('partial membership can be selected to add missing books', () async {
      repository.seedCollectionSourceIds({
        'reading': {'book-1'},
      });
      await cubit.load(sourceIds: {'book-1', 'book-2'});
      cubit.toggleCollection('reading');

      expect(cubit.state.selectedCollectionIds, {'reading'});
      expect(
        await cubit.submitSelected(sourceIds: ['book-1', 'book-2']),
        isTrue,
      );
      expect(repository.addedSourceIdsByCollection['reading'], {
        'book-1',
        'book-2',
      });
    });

    test(
      'confirmation writes all destinations in one repository call',
      () async {
        await cubit.load(sourceIds: {'book-1', 'book-2'});
        cubit
          ..toggleCollection('reading')
          ..toggleCollection(CollectionRepository.favouritesCollectionId);

        expect(
          await cubit.submitSelected(sourceIds: ['book-1', 'book-2', 'book-1']),
          isTrue,
        );
        expect(repository.batchWrites, 1);
        expect(repository.submittedCollectionIds, {
          'reading',
          CollectionRepository.favouritesCollectionId,
        });
        expect(repository.submittedSourceIds, {'book-1', 'book-2'});
        expect(repository.collectionReads, 1);
        expect(cubit.state.selectedCollectionIds, isEmpty);
        expect(cubit.state.containingAll, {
          'reading',
          CollectionRepository.favouritesCollectionId,
        });
      },
    );

    test('empty selections and empty sources do not write', () async {
      await cubit.load(sourceIds: {'book'});
      expect(await cubit.submitSelected(sourceIds: ['book']), isFalse);
      cubit.toggleCollection('reading');
      expect(await cubit.submitSelected(sourceIds: []), isFalse);
      expect(repository.batchWrites, 0);
      expect(cubit.state.selectedCollectionIds, {'reading'});
    });

    test('failure keeps the draft available for retry', () async {
      await cubit.load(sourceIds: {'book'});
      cubit
        ..searchCollections('Read')
        ..toggleCollection('reading');
      repository.shouldThrow = true;

      expect(await cubit.submitSelected(sourceIds: ['book']), isFalse);
      expect(
        cubit.state.errorCode,
        AddToCollectionErrorCode.updateCollectionFailed,
      );
      expect(cubit.state.selectedCollectionIds, {'reading'});
      expect(cubit.state.searchQuery, 'read');

      repository.shouldThrow = false;
      expect(await cubit.submitSelected(sourceIds: ['book']), isTrue);
      expect(repository.batchWrites, 2);
      expect(repository.addedSourceIdsByCollection['reading'], {'book'});
      expect(cubit.state.errorCode, isNull);
    });

    test(
      'successful writes do not fail when later reads are unavailable',
      () async {
        await cubit.load(sourceIds: {'book'});
        cubit.toggleCollection('reading');
        repository.rejectReadsAfterWrite = true;

        expect(await cubit.submitSelected(sourceIds: ['book']), isTrue);
        expect(repository.collectionReads, 1);
        expect(cubit.state.status, AddToCollectionStatus.success);
        expect(cubit.state.errorCode, isNull);
      },
    );

    test(
      'pending writes block duplicate confirmation and draft changes',
      () async {
        await cubit.load(sourceIds: {'book'});
        cubit.toggleCollection('reading');
        repository.writeGate = Completer<void>();
        final first = cubit.submitSelected(sourceIds: ['book']);

        expect(cubit.state.status, AddToCollectionStatus.submitting);
        cubit
          ..toggleCollection('research')
          ..searchCollections('research');
        expect(await cubit.submitSelected(sourceIds: ['book']), isFalse);
        expect(await cubit.createCollection(name: 'Busy'), isFalse);
        expect(repository.batchWrites, 1);
        expect(cubit.state.selectedCollectionIds, {'reading'});
        expect(cubit.state.searchQuery, isEmpty);

        repository.writeGate!.complete();
        expect(await first, isTrue);
      },
    );

    test('closing during confirmation prevents late state and reads', () async {
      await cubit.load(sourceIds: {'book'});
      cubit.toggleCollection('reading');
      repository.writeGate = Completer<void>();
      final pending = cubit.submitSelected(sourceIds: ['book']);
      final stateAtClose = cubit.state;
      await cubit.close();
      repository.writeGate!.complete();

      expect(await pending, isFalse);
      expect(cubit.state, stateAtClose);
      expect(repository.collectionReads, 1);
      expect(repository.addedSourceIdsByCollection['reading'], {'book'});
    });

    test(
      'search is case insensitive and preserves hidden selections',
      () async {
        await cubit.load(sourceIds: {'book'});
        cubit
          ..toggleCollection('reading')
          ..searchCollections('  RESEARCH ');

        expect(cubit.state.searchQuery, 'research');
        expect(cubit.state.visibleCollections.map((c) => c.id), ['research']);
        expect(cubit.state.selectedCollectionIds, {'reading'});
        expect(cubit.state.matchesSearch('Research notes'), isTrue);
        expect(cubit.state.matchesSearch('Favourites'), isFalse);
        cubit.searchCollections('');
        expect(cubit.state.visibleCollections, hasLength(2));
        expect(repository.collectionReads, 1);
      },
    );

    test(
      'a new flow resets the draft and applies the new source snapshot',
      () async {
        repository.seedCollectionSourceIds({
          'research': {'another-book'},
        });
        await cubit.load(sourceIds: {'book'});
        cubit
          ..toggleCollection('reading')
          ..searchCollections('read');

        await cubit.load(sourceIds: {'another-book'});

        expect(cubit.state.selectedCollectionIds, isEmpty);
        expect(cubit.state.searchQuery, isEmpty);
        expect(cubit.state.containingAll, {'research'});
      },
    );

    test('retrying a load preserves the current draft', () async {
      await cubit.load(sourceIds: {'book'});
      cubit
        ..toggleCollection('reading')
        ..searchCollections('read');
      repository.shouldThrow = true;
      await cubit.load();
      repository.shouldThrow = false;
      await cubit.load();

      expect(cubit.state.selectedCollectionIds, {'reading'});
      expect(cubit.state.searchQuery, 'read');
    });

    test(
      'new collection is selected without adding books or rereading',
      () async {
        await cubit.load(sourceIds: {'book'});
        cubit
          ..toggleCollection('reading')
          ..searchCollections('read');

        expect(await cubit.createCollection(name: '  Design  '), isTrue);
        final collection = cubit.state.collections.first;
        expect(collection.name, 'Design');
        expect(collection.sourceCount, 0);
        expect(cubit.state.selectedCollectionIds, {'reading', collection.id});
        expect(cubit.state.searchQuery, isEmpty);
        expect(repository.addedSourceIdsByCollection[collection.id], isEmpty);
        expect(repository.collectionReads, 1);
        expect(repository.batchWrites, 0);

        expect(await cubit.submitSelected(sourceIds: ['book']), isTrue);
        expect(repository.addedSourceIdsByCollection[collection.id], {'book'});
        expect(repository.addedSourceIdsByCollection['reading'], {'book'});
      },
    );

    test(
      'invalid or failed creation preserves existing destination choices',
      () async {
        await cubit.load(sourceIds: {'book'});
        cubit.toggleCollection('reading');

        expect(await cubit.createCollection(name: '   '), isFalse);
        expect(
          cubit.state.errorCode,
          AddToCollectionErrorCode.collectionNameRequired,
        );
        expect(cubit.state.collections, hasLength(2));
        expect(cubit.state.selectedCollectionIds, {'reading'});

        repository.shouldThrow = true;
        expect(await cubit.createCollection(name: 'Design'), isFalse);
        expect(
          cubit.state.errorCode,
          AddToCollectionErrorCode.createCollectionFailed,
        );
        expect(cubit.state.collections, hasLength(2));
        expect(cubit.state.selectedCollectionIds, {'reading'});
      },
    );
  });
}

LibraryCollection _collection(String id, String name) => LibraryCollection(
  id: id,
  name: name,
  sourceCount: 0,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

class _RecordingCollectionRepository extends FakeCollectionRepository {
  int batchWrites = 0;
  int collectionReads = 0;
  Set<String>? submittedCollectionIds;
  Set<String>? submittedSourceIds;
  bool rejectReadsAfterWrite = false;

  @override
  Future<List<LibraryCollection>> getCollections() {
    collectionReads++;
    if (rejectReadsAfterWrite && batchWrites > 0) {
      throw StorageException(cause: 'read unavailable after commit');
    }
    return super.getCollections();
  }

  @override
  Future<void> addSourcesToCollections({
    required Iterable<String> collectionIds,
    required Iterable<String> sourceIds,
  }) {
    batchWrites++;
    submittedCollectionIds = collectionIds.toSet();
    submittedSourceIds = sourceIds.toSet();
    return super.addSourcesToCollections(
      collectionIds: collectionIds,
      sourceIds: sourceIds,
    );
  }
}
