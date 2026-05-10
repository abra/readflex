part of 'source_details_bloc.dart';

enum SourceDetailsStatus { initial, loading, success, notFound, failure }

class SourceDetailsState extends Equatable {
  const SourceDetailsState({
    this.status = SourceDetailsStatus.initial,
    this.source,
    this.fileSizeBytes,
  });

  final SourceDetailsStatus status;
  final Book? source;
  final int? fileSizeBytes;

  SourceDetailsState copyWith({
    SourceDetailsStatus? status,
    Book? source,
    Object? fileSizeBytes = _absent,
  }) => SourceDetailsState(
    status: status ?? this.status,
    source: source ?? this.source,
    fileSizeBytes: fileSizeBytes == _absent
        ? this.fileSizeBytes
        : fileSizeBytes as int?,
  );

  @override
  List<Object?> get props => [status, source, fileSizeBytes];
}

const _absent = Object();
