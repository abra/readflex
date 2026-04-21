part of 'reader_bloc.dart';

sealed class ReaderEvent extends Equatable {
  const ReaderEvent();

  @override
  List<Object?> get props => [];
}

final class ReaderSourceLoadRequested extends ReaderEvent {
  const ReaderSourceLoadRequested({required this.sourceId});

  final String sourceId;

  @override
  List<Object?> get props => [sourceId];
}

final class ReaderBookPositionUpdated extends ReaderEvent {
  const ReaderBookPositionUpdated({
    required this.cfi,
    required this.progress,
  });

  final String cfi;
  final double progress;

  @override
  List<Object?> get props => [cfi, progress];
}

final class ReaderArticlePositionUpdated extends ReaderEvent {
  const ReaderArticlePositionUpdated({required this.scrollOffset});

  final double scrollOffset;

  @override
  List<Object?> get props => [scrollOffset];
}

final class ReaderHighlightsRefreshed extends ReaderEvent {
  const ReaderHighlightsRefreshed();
}
