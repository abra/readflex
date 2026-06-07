part of 'manage_collection_cubit.dart';

enum ManageCollectionStatus { idle, submitting, success, failure }

class ManageCollectionState extends Equatable {
  const ManageCollectionState({
    this.status = ManageCollectionStatus.idle,
    this.errorMessage,
  });

  final ManageCollectionStatus status;
  final String? errorMessage;

  bool get isBusy => status == ManageCollectionStatus.submitting;

  ManageCollectionState copyWith({
    ManageCollectionStatus? status,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ManageCollectionState(
      status: status ?? this.status,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, errorMessage];
}
