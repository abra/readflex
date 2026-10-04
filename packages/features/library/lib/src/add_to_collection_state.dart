part of 'add_to_collection_cubit.dart';

enum AddToCollectionStatus { initial, loading, success, submitting, failure }

enum AddToCollectionErrorCode {
  loadCollectionsFailed,
  updateCollectionFailed,
  updateFavouritesFailed,
  collectionNameRequired,
  createCollectionFailed,
}

class AddToCollectionState extends Equatable {
  const AddToCollectionState({
    this.status = AddToCollectionStatus.initial,
    this.collections = const [],
    this.favouritesSourceCount = 0,
    this.errorCode,
    this.containingAll = const {},
  });

  final AddToCollectionStatus status;
  final List<LibraryCollection> collections;
  final int favouritesSourceCount;
  final AddToCollectionErrorCode? errorCode;
  final Set<String> containingAll;

  bool get isBusy =>
      status == AddToCollectionStatus.loading ||
      status == AddToCollectionStatus.submitting;

  AddToCollectionState copyWith({
    AddToCollectionStatus? status,
    List<LibraryCollection>? collections,
    int? favouritesSourceCount,
    AddToCollectionErrorCode? errorCode,
    bool clearError = false,
    Set<String>? containingAll,
  }) {
    return AddToCollectionState(
      status: status ?? this.status,
      collections: collections ?? this.collections,
      favouritesSourceCount:
          favouritesSourceCount ?? this.favouritesSourceCount,
      errorCode: clearError ? null : errorCode ?? this.errorCode,
      containingAll: containingAll ?? this.containingAll,
    );
  }

  @override
  List<Object?> get props => [
    status,
    collections,
    favouritesSourceCount,
    errorCode,
    containingAll,
  ];
}
