import 'package:collection_repository/collection_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'add_to_collection_state.dart';

class AddToCollectionCubit extends Cubit<AddToCollectionState> {
  AddToCollectionCubit({required CollectionRepository collectionRepository})
    : _collectionRepository = collectionRepository,
      super(const AddToCollectionState());

  final CollectionRepository _collectionRepository;

  Future<void> load() async {
    emit(
      state.copyWith(status: AddToCollectionStatus.loading, clearError: true),
    );
    try {
      final collections = await _collectionRepository.getCollections();
      emit(
        state.copyWith(
          status: AddToCollectionStatus.success,
          collections: collections,
          clearError: true,
        ),
      );
    } catch (e, st) {
      addError(e, st);
      emit(
        state.copyWith(
          status: AddToCollectionStatus.failure,
          errorMessage: 'Failed to load collections',
        ),
      );
    }
  }

  Future<void> addToCollection({
    required String collectionId,
    required Iterable<String> sourceIds,
  }) async {
    emit(
      state.copyWith(
        status: AddToCollectionStatus.submitting,
        clearError: true,
      ),
    );
    try {
      await _collectionRepository.addSourcesToCollection(
        collectionId: collectionId,
        sourceIds: sourceIds,
      );
      final collections = await _collectionRepository.getCollections();
      emit(
        state.copyWith(
          status: AddToCollectionStatus.success,
          collections: collections,
          clearError: true,
        ),
      );
    } catch (e, st) {
      addError(e, st);
      emit(
        state.copyWith(
          status: AddToCollectionStatus.failure,
          errorMessage: 'Failed to update collection',
        ),
      );
    }
  }

  Future<void> createAndAdd({
    required String name,
    required Iterable<String> sourceIds,
  }) async {
    emit(
      state.copyWith(
        status: AddToCollectionStatus.submitting,
        clearError: true,
      ),
    );
    try {
      await _collectionRepository.createCollectionWithSources(
        name: name,
        sourceIds: sourceIds,
      );
      final collections = await _collectionRepository.getCollections();
      emit(
        state.copyWith(
          status: AddToCollectionStatus.success,
          collections: collections,
          clearError: true,
        ),
      );
    } on ArgumentError catch (e, st) {
      addError(e, st);
      emit(
        state.copyWith(
          status: AddToCollectionStatus.failure,
          errorMessage: 'Collection name is required',
        ),
      );
    } catch (e, st) {
      addError(e, st);
      emit(
        state.copyWith(
          status: AddToCollectionStatus.failure,
          errorMessage: 'Failed to create collection',
        ),
      );
    }
  }
}
