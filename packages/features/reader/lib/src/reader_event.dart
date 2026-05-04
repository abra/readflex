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
///
/// [atEnd] is `true` when foliate-js's paginator reports we're on its
/// trailing blank-buffer pages past the actual content. On those pages
/// foliate-js still emits `progress=0` / `bookCurrentPage=0`; the bloc
/// uses [atEnd] to override those bogus numbers with "100% / last page".
final class ReaderBookPositionUpdated extends ReaderEvent {
  const ReaderBookPositionUpdated({
    required this.cfi,
    required this.progress,
    this.chapterTitle,
    this.bookCurrentPage,
    this.bookTotalPages,
    this.sizeTotal,
    this.atEnd = false,
  });

  final String cfi;
  final double progress;
  final String? chapterTitle;
  final int? bookCurrentPage;
  final int? bookTotalPages;

  /// Total byte size of all linear sections, surfaced so the bottom-chrome
  /// slider can predict `bookCurrentPage` exactly during drag. See
  /// [BookPosition.sizeTotal] for the full rationale.
  final int? sizeTotal;
  final bool atEnd;

  @override
  List<Object?> get props => [
    cfi,
    progress,
    chapterTitle,
    bookCurrentPage,
    bookTotalPages,
    sizeTotal,
    atEnd,
  ];
}

/// Reloads the highlight list from storage after a TextAction
/// (Highlight / Flashcard) mutated it.
final class ReaderHighlightsRefreshed extends ReaderEvent {
  const ReaderHighlightsRefreshed();
}
