part of 'add_to_collection_cubit.dart';

enum AddToCollectionStatus { initial, loading, success, submitting, failure }

class AddToCollectionState extends Equatable {
  const AddToCollectionState({
    this.status = AddToCollectionStatus.initial,
    this.collections = const [],
    this.errorMessage,
  });

  final AddToCollectionStatus status;
  final List<LibraryCollection> collections;
  final String? errorMessage;

  bool get isBusy =>
      status == AddToCollectionStatus.loading ||
      status == AddToCollectionStatus.submitting;

  AddToCollectionState copyWith({
    AddToCollectionStatus? status,
    List<LibraryCollection>? collections,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AddToCollectionState(
      status: status ?? this.status,
      collections: collections ?? this.collections,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, collections, errorMessage];
}
