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
/// only stored on the in-memory state for overlays/debug UI, not persisted.
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
    this.chapterCurrentPage,
    this.chapterTotalPages,
    this.sizeTotal,
    this.pageProgressionRtl,
    this.atStart = false,
    this.atEnd = false,
    this.currentPageBookmarked = false,
    this.currentPageBookmarkCfi,
    this.currentPageBookmarkId,
  });

  final String cfi;
  final double progress;
  final String? chapterTitle;
  final int? bookCurrentPage;
  final int? bookTotalPages;

  /// Page index / total within the current section (0-indexed). For EPUB
  /// these are visual columns inside the active chapter; for CBZ each
  /// comic page is its own section, so the pair becomes "comic page X /
  /// total comic pages" — the only useful counter for that format since
  /// `bookCurrentPage` collapses comics into 1–4 byte locations.
  final int? chapterCurrentPage;
  final int? chapterTotalPages;

  /// Total byte size of all linear sections. See [BookPosition.sizeTotal]
  /// for the full rationale.
  final int? sizeTotal;

  /// True when foliate-js reports right-to-left page progression. Null means
  /// this event does not know and the current state should be preserved.
  final bool? pageProgressionRtl;

  final bool atStart;
  final bool atEnd;
  final bool currentPageBookmarked;
  final String? currentPageBookmarkCfi;
  final String? currentPageBookmarkId;

  @override
  List<Object?> get props => [
    cfi,
    progress,
    chapterTitle,
    bookCurrentPage,
    bookTotalPages,
    chapterCurrentPage,
    chapterTotalPages,
    sizeTotal,
    pageProgressionRtl,
    atStart,
    atEnd,
    currentPageBookmarked,
    currentPageBookmarkCfi,
    currentPageBookmarkId,
  ];
}

/// Reloads the highlight list from storage after a TextAction mutated it.
final class ReaderHighlightsRefreshed extends ReaderEvent {
  const ReaderHighlightsRefreshed();
}

/// foliate-js parsed the book table of contents.
final class ReaderTocUpdated extends ReaderEvent {
  const ReaderTocUpdated({required this.items});

  final List<ReaderTocItem> items;

  @override
  List<Object?> get props => [items];
}

/// foliate-js reported optional document capabilities such as embedded TOC or
/// searchable OCR/text layer availability.
final class ReaderDocumentFeaturesUpdated extends ReaderEvent {
  const ReaderDocumentFeaturesUpdated({required this.features});

  final ReaderDocumentFeatures features;

  @override
  List<Object?> get props => [features];
}

/// foliate-js requested adding/removing a bookmark at the current page.
final class ReaderBookmarkChanged extends ReaderEvent {
  const ReaderBookmarkChanged({
    required this.remove,
    required this.cfi,
    required this.content,
    required this.progress,
    this.id,
    this.anchorExact,
    this.anchorPrefix,
    this.anchorSuffix,
    this.anchorSectionIndex,
    this.anchorSectionPage,
  });

  final bool remove;
  final String? id;
  final String cfi;
  final String content;
  final double progress;
  final String? anchorExact;
  final String? anchorPrefix;
  final String? anchorSuffix;
  final int? anchorSectionIndex;
  final int? anchorSectionPage;

  @override
  List<Object?> get props => [
    remove,
    id,
    cfi,
    content,
    progress,
    anchorExact,
    anchorPrefix,
    anchorSuffix,
    anchorSectionIndex,
    anchorSectionPage,
  ];
}
