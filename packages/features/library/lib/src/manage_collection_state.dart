part of 'manage_collection_cubit.dart';

enum ManageCollectionStatus { idle, submitting, success, failure }

enum ManageCollectionErrorCode {
  collectionNameRequired,
  saveCollectionFailed,
  deleteCollectionFailed,
}

class ManageCollectionState extends Equatable {
  const ManageCollectionState({
    this.status = ManageCollectionStatus.idle,
    this.errorCode,
  });

  final ManageCollectionStatus status;
  final ManageCollectionErrorCode? errorCode;

  bool get isBusy => status == ManageCollectionStatus.submitting;

  ManageCollectionState copyWith({
    ManageCollectionStatus? status,
    ManageCollectionErrorCode? errorCode,
    bool clearError = false,
  }) {
    return ManageCollectionState(
      status: status ?? this.status,
      errorCode: clearError ? null : errorCode ?? this.errorCode,
    );
  }

  @override
  List<Object?> get props => [status, errorCode];
}
