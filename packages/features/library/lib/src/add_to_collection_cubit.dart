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
  Set<String> _sourceIds = const {};

  void clearError() {
    if (!isClosed &&
        !state.isBusy &&
        state.errorCode != AddToCollectionErrorCode.loadCollectionsFailed) {
      emit(
        state.copyWith(status: AddToCollectionStatus.success, clearError: true),
      );
    }
  }

  Future<void> load({Set<String>? sourceIds}) async {
    if (isClosed || state.isBusy) return;
    if (sourceIds != null) _sourceIds = Set.unmodifiable(sourceIds);
    emit(
      state.copyWith(status: AddToCollectionStatus.loading, clearError: true),
    );
    try {
      final snapshot = await _loadSnapshot();
      if (isClosed) return;
      emit(
        state.copyWith(
          status: AddToCollectionStatus.success,
          collections: snapshot.collections,
          favouritesSourceCount: snapshot.favouritesSourceCount,
          containingAll: snapshot.containingAll,
          clearError: true,
        ),
      );
    } catch (e, st) {
      if (isClosed) return;
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
    if (state.isBusy || isClosed) return;
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
      if (isClosed) return;
      final snapshot = await _loadSnapshot();
      if (isClosed) return;
      emit(
        state.copyWith(
          status: AddToCollectionStatus.success,
          collections: snapshot.collections,
          favouritesSourceCount: snapshot.favouritesSourceCount,
          containingAll: snapshot.containingAll,
          clearError: true,
        ),
      );
    } catch (e, st) {
      if (isClosed) return;
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
    if (state.isBusy || isClosed) return;
    emit(
      state.copyWith(
        status: AddToCollectionStatus.submitting,
        clearError: true,
      ),
    );
    try {
      await _collectionRepository.addSourcesToFavourites(sourceIds: sourceIds);
      if (isClosed) return;
      final snapshot = await _loadSnapshot();
      if (isClosed) return;
      emit(
        state.copyWith(
          status: AddToCollectionStatus.success,
          collections: snapshot.collections,
          favouritesSourceCount: snapshot.favouritesSourceCount,
          containingAll: snapshot.containingAll,
          clearError: true,
        ),
      );
    } catch (e, st) {
      if (isClosed) return;
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
    if (state.isBusy || isClosed) return;
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
      if (isClosed) return;
      final snapshot = await _loadSnapshot();
      if (isClosed) return;
      emit(
        state.copyWith(
          status: AddToCollectionStatus.success,
          collections: snapshot.collections,
          favouritesSourceCount: snapshot.favouritesSourceCount,
          containingAll: snapshot.containingAll,
          clearError: true,
        ),
      );
    } on ArgumentError catch (e, st) {
      if (isClosed) return;
      addError(e, st);
      emit(
        state.copyWith(
          status: AddToCollectionStatus.failure,
          errorCode: AddToCollectionErrorCode.collectionNameRequired,
        ),
      );
    } catch (e, st) {
      if (isClosed) return;
      addError(e, st);
      emit(
        state.copyWith(
          status: AddToCollectionStatus.failure,
          errorCode: AddToCollectionErrorCode.createCollectionFailed,
        ),
      );
    }
  }

  Future<
    ({
      List<LibraryCollection> collections,
      int favouritesSourceCount,
      Set<String> containingAll,
    })
  >
  _loadSnapshot() async {
    final collections = await _collectionRepository.getCollections();
    final favouriteSourceIds = await _collectionRepository
        .getFavouriteSourceIds();
    final containingAll = _sourceIds.isEmpty
        ? const <String>{}
        : await _collectionRepository.collectionsContainingAll(_sourceIds);
    return (
      collections: collections,
      favouritesSourceCount: favouriteSourceIds.length,
      containingAll: containingAll,
    );
  }
}
