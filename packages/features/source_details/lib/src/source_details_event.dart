part of 'source_details_bloc.dart';

sealed class SourceDetailsEvent extends Equatable {
  const SourceDetailsEvent();

  @override
  List<Object?> get props => [];
}

final class SourceDetailsLoadRequested extends SourceDetailsEvent {
  const SourceDetailsLoadRequested(this.sourceId);

  final String sourceId;

  @override
  List<Object?> get props => [sourceId];
}
