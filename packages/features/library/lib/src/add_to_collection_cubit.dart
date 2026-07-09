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
      final snapshot = await _loadSnapshot();
      emit(
        state.copyWith(
          status: AddToCollectionStatus.success,
          collections: snapshot.collections,
          favouritesSourceCount: snapshot.favouritesSourceCount,
          clearError: true,
        ),
      );
    } catch (e, st) {
      addError(e, st);
      emit(
        state.copyWith(
          status: AddToCollectionStatus.failure,
          errorCode: AddToCollectionErrorCode.loadCollectionsFailed,
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
      final snapshot = await _loadSnapshot();
      emit(
        state.copyWith(
          status: AddToCollectionStatus.success,
          collections: snapshot.collections,
          favouritesSourceCount: snapshot.favouritesSourceCount,
          clearError: true,
        ),
      );
    } catch (e, st) {
      addError(e, st);
      emit(
        state.copyWith(
          status: AddToCollectionStatus.failure,
          errorCode: AddToCollectionErrorCode.updateCollectionFailed,
        ),
      );
    }
  }

  Future<void> addToFavourites({required Iterable<String> sourceIds}) async {
    emit(
      state.copyWith(
        status: AddToCollectionStatus.submitting,
        clearError: true,
      ),
    );
    try {
      await _collectionRepository.addSourcesToFavourites(sourceIds: sourceIds);
      final snapshot = await _loadSnapshot();
      emit(
        state.copyWith(
          status: AddToCollectionStatus.success,
          collections: snapshot.collections,
          favouritesSourceCount: snapshot.favouritesSourceCount,
          clearError: true,
        ),
      );
    } catch (e, st) {
      addError(e, st);
      emit(
        state.copyWith(
          status: AddToCollectionStatus.failure,
          errorCode: AddToCollectionErrorCode.updateFavouritesFailed,
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
      final snapshot = await _loadSnapshot();
      emit(
        state.copyWith(
          status: AddToCollectionStatus.success,
          collections: snapshot.collections,
          favouritesSourceCount: snapshot.favouritesSourceCount,
          clearError: true,
        ),
      );
    } on ArgumentError catch (e, st) {
      addError(e, st);
      emit(
        state.copyWith(
          status: AddToCollectionStatus.failure,
          errorCode: AddToCollectionErrorCode.collectionNameRequired,
        ),
      );
    } catch (e, st) {
      addError(e, st);
      emit(
        state.copyWith(
          status: AddToCollectionStatus.failure,
          errorCode: AddToCollectionErrorCode.createCollectionFailed,
        ),
      );
    }
  }

  Future<({List<LibraryCollection> collections, int favouritesSourceCount})>
  _loadSnapshot() async {
    final collections = await _collectionRepository.getCollections();
    final favouriteSourceIds = await _collectionRepository
        .getFavouriteSourceIds();
    return (
      collections: collections,
      favouritesSourceCount: favouriteSourceIds.length,
    );
  }
}
