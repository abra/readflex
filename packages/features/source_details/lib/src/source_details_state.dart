part of 'source_details_bloc.dart';

enum SourceDetailsStatus { initial, loading, success, notFound, failure }

class SourceDetailsState extends Equatable {
  const SourceDetailsState({
    this.status = SourceDetailsStatus.initial,
    this.source,
  });

  final SourceDetailsStatus status;
  final Book? source;

  SourceDetailsState copyWith({
    SourceDetailsStatus? status,
    Book? source,
  }) => SourceDetailsState(
    status: status ?? this.status,
    source: source ?? this.source,
  );

  @override
  List<Object?> get props => [status, source];
}
