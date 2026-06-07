import 'package:collection_repository/collection_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'manage_collection_state.dart';

class ManageCollectionCubit extends Cubit<ManageCollectionState> {
  ManageCollectionCubit({required CollectionRepository collectionRepository})
    : _collectionRepository = collectionRepository,
      super(const ManageCollectionState());

  final CollectionRepository _collectionRepository;

  Future<bool> saveChanges({
    required String collectionId,
    String? name,
    Iterable<String> removedSourceIds = const [],
  }) async {
    emit(
      state.copyWith(
        status: ManageCollectionStatus.submitting,
        clearError: true,
      ),
    );
    try {
      await _collectionRepository.updateCollection(
        collectionId: collectionId,
        name: name,
        removedSourceIds: removedSourceIds,
      );
      emit(
        state.copyWith(
          status: ManageCollectionStatus.success,
          clearError: true,
        ),
      );
      return true;
    } on ArgumentError catch (e, st) {
      addError(e, st);
      emit(
        state.copyWith(
          status: ManageCollectionStatus.failure,
          errorMessage: 'Collection name is required',
        ),
      );
      return false;
    } catch (e, st) {
      addError(e, st);
      emit(
        state.copyWith(
          status: ManageCollectionStatus.failure,
          errorMessage: 'Failed to save collection',
        ),
      );
      return false;
    }
  }

  Future<bool> deleteCollection(String collectionId) async {
    emit(
      state.copyWith(
        status: ManageCollectionStatus.submitting,
        clearError: true,
      ),
    );
    try {
      await _collectionRepository.deleteCollection(collectionId);
      emit(
        state.copyWith(
          status: ManageCollectionStatus.success,
          clearError: true,
        ),
      );
      return true;
    } catch (e, st) {
      addError(e, st);
      emit(
        state.copyWith(
          status: ManageCollectionStatus.failure,
          errorMessage: 'Failed to delete collection',
        ),
      );
      return false;
    }
  }
}
