part of 'add_to_collection_cubit.dart';

enum AddToCollectionStatus { initial, loading, success, submitting, failure }

class AddToCollectionState extends Equatable {
  const AddToCollectionState({
    this.status = AddToCollectionStatus.initial,
    this.collections = const [],
    this.favouritesSourceCount = 0,
    this.errorMessage,
  });

  final AddToCollectionStatus status;
  final List<LibraryCollection> collections;
  final int favouritesSourceCount;
  final String? errorMessage;

  bool get isBusy =>
      status == AddToCollectionStatus.loading ||
      status == AddToCollectionStatus.submitting;

  AddToCollectionState copyWith({
    AddToCollectionStatus? status,
    List<LibraryCollection>? collections,
    int? favouritesSourceCount,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AddToCollectionState(
      status: status ?? this.status,
      collections: collections ?? this.collections,
      favouritesSourceCount:
          favouritesSourceCount ?? this.favouritesSourceCount,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    collections,
    favouritesSourceCount,
    errorMessage,
  ];
}
