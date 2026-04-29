part of 'reader_bloc.dart';

sealed class ReaderEvent extends Equatable {
  const ReaderEvent();

  @override
  List<Object?> get props => [];
}

/// Fired once when [ReaderScreen] mounts — resolves the source and loads
/// its highlights.
final class ReaderSourceLoadRequested extends ReaderEvent {
  const ReaderSourceLoadRequested({required this.sourceId});

  final String sourceId;

  @override
  List<Object?> get props => [sourceId];
}

/// foliate-js reports a new reading position. Persisted to the book's
/// `currentCfi` + `readingProgress`.
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

/// Reloads the highlight list from storage after a TextAction
/// (Highlight / Flashcard) mutated it.
final class ReaderHighlightsRefreshed extends ReaderEvent {
  const ReaderHighlightsRefreshed();
}
