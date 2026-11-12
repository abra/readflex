import 'package:collection_repository/collection_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'add_to_collection_state.dart';

class AddToCollectionCubit extends Cubit<AddToCollectionState> {
  AddToCollectionCubit({required this._collectionRepository})
    : super(const AddToCollectionState());

  final CollectionRepository _collectionRepository;
  Set<String> _sourceIds = const {};

  void toggleCollection(String collectionId) {
    if (isClosed ||
        state.isBusy ||
        state.containingAll.contains(collectionId)) {
      return;
    }
    if (collectionId != CollectionRepository.favouritesCollectionId &&
        !state.collections.any((collection) => collection.id == collectionId)) {
      return;
    }
    final selected = state.selectedCollectionIds.toSet();
    if (!selected.add(collectionId)) selected.remove(collectionId);
    emit(
      state.copyWith(
        selectedCollectionIds: Set.unmodifiable(selected),
        status: AddToCollectionStatus.success,
        clearError: true,
      ),
    );
  }

  void searchCollections(String query) {
    if (isClosed || state.isBusy) return;
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery == state.searchQuery) return;
    emit(state.copyWith(searchQuery: normalizedQuery));
  }

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
      state.copyWith(
        status: AddToCollectionStatus.loading,
        selectedCollectionIds: sourceIds == null ? null : const {},
        searchQuery: sourceIds == null ? null : '',
        clearError: true,
      ),
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

  Future<bool> submitSelected({required Iterable<String> sourceIds}) async {
    if (isClosed || !state.canSubmit) return false;
    final ids = Set<String>.unmodifiable(sourceIds);
    if (ids.isEmpty) return false;
    final collectionIds = state.selectedCollectionIds;
    emit(
      state.copyWith(
        status: AddToCollectionStatus.submitting,
        clearError: true,
      ),
    );
    try {
      await _collectionRepository.addSourcesToCollections(
        collectionIds: collectionIds,
        sourceIds: ids,
      );
      if (isClosed) return false;
      // The write committed. A subsequent read must not turn it into a failure.
      emit(
        state.copyWith(
          status: AddToCollectionStatus.success,
          selectedCollectionIds: const {},
          containingAll: _sourceIds.isNotEmpty && ids.containsAll(_sourceIds)
              ? Set.unmodifiable({...state.containingAll, ...collectionIds})
              : null,
          clearError: true,
        ),
      );
      return true;
    } catch (e, st) {
      if (isClosed) return false;
      addError(e, st);
      emit(
        state.copyWith(
          status: AddToCollectionStatus.failure,
          errorCode: AddToCollectionErrorCode.updateCollectionFailed,
        ),
      );
      return false;
    }
  }

  Future<bool> createCollection({required String name}) async {
    if (isClosed || state.isBusy) return false;
    emit(
      state.copyWith(
        status: AddToCollectionStatus.submitting,
        clearError: true,
      ),
    );
    try {
      final collection = await _collectionRepository.createCollection(name);
      if (isClosed) return false;
      emit(
        state.copyWith(
          status: AddToCollectionStatus.success,
          collections: List.unmodifiable([collection, ...state.collections]),
          selectedCollectionIds: Set.unmodifiable({
            ...state.selectedCollectionIds,
            collection.id,
          }),
          searchQuery: '',
          clearError: true,
        ),
      );
      return true;
    } on ArgumentError catch (e, st) {
      if (isClosed) return false;
      addError(e, st);
      emit(
        state.copyWith(
          status: AddToCollectionStatus.failure,
          errorCode: AddToCollectionErrorCode.collectionNameRequired,
        ),
      );
      return false;
    } catch (e, st) {
      if (isClosed) return false;
      addError(e, st);
      emit(
        state.copyWith(
          status: AddToCollectionStatus.failure,
          errorCode: AddToCollectionErrorCode.createCollectionFailed,
        ),
      );
      return false;
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
