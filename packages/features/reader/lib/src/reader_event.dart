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
/// `currentCfi` + `readingProgress`. Optional chapter/page fields are
/// only stored on the in-memory state (chrome UI), not persisted.
final class ReaderBookPositionUpdated extends ReaderEvent {
  const ReaderBookPositionUpdated({
    required this.cfi,
    required this.progress,
    this.chapterTitle,
    this.bookCurrentPage,
    this.bookTotalPages,
  });

  final String cfi;
  final double progress;
  final String? chapterTitle;
  final int? bookCurrentPage;
  final int? bookTotalPages;

  @override
  List<Object?> get props => [
    cfi,
    progress,
    chapterTitle,
    bookCurrentPage,
    bookTotalPages,
  ];
}

/// Reloads the highlight list from storage after a TextAction
/// (Highlight / Flashcard) mutated it.
final class ReaderHighlightsRefreshed extends ReaderEvent {
  const ReaderHighlightsRefreshed();
}
