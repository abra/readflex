part of 'add_to_collection_cubit.dart';

enum AddToCollectionStatus { initial, loading, success, submitting, failure }

enum AddToCollectionErrorCode {
  loadCollectionsFailed,
  updateCollectionFailed,
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
    this.selectedCollectionIds = const {},
    this.searchQuery = '',
  });

  final AddToCollectionStatus status;
  final List<LibraryCollection> collections;
  final int favouritesSourceCount;
  final AddToCollectionErrorCode? errorCode;
  final Set<String> containingAll;
  final Set<String> selectedCollectionIds;
  final String searchQuery;

  int get selectedDestinationCount => selectedCollectionIds.length;

  bool get canSubmit => !isBusy && selectedCollectionIds.isNotEmpty;

  List<LibraryCollection> get visibleCollections => searchQuery.isEmpty
      ? collections
      : collections
            .where((collection) => matchesSearch(collection.name))
            .toList(growable: false);

  bool matchesSearch(String label) =>
      searchQuery.isEmpty || label.toLowerCase().contains(searchQuery);

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
    Set<String>? selectedCollectionIds,
    String? searchQuery,
  }) {
    return AddToCollectionState(
      status: status ?? this.status,
      collections: collections ?? this.collections,
      favouritesSourceCount:
          favouritesSourceCount ?? this.favouritesSourceCount,
      errorCode: clearError ? null : errorCode ?? this.errorCode,
      containingAll: containingAll ?? this.containingAll,
      selectedCollectionIds:
          selectedCollectionIds ?? this.selectedCollectionIds,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  @override
  List<Object?> get props => [
    status,
    collections,
    favouritesSourceCount,
    errorCode,
    containingAll,
    selectedCollectionIds,
    searchQuery,
  ];
}
