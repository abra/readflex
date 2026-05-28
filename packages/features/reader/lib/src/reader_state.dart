part of 'reader_bloc.dart';

enum ReaderStatus { initial, loading, ready, failure }

/// Snapshot of the loaded book and its highlights. Highlights are loaded
/// alongside the book and refreshed on demand via [ReaderHighlightsRefreshed].
class ReaderState extends Equatable {
  const ReaderState({
    this.status = ReaderStatus.initial,
    this.title = '',
    this.book,
    this.sourceType = SourceType.book,
    this.pageProgressionRtl = false,
    this.highlights = const [],
    this.bookmarks = const [],
    this.tocItems = const [],
    this.chapterTitle,
    this.bookCurrentPage,
    this.bookTotalPages,
    this.chapterCurrentPage,
    this.chapterTotalPages,
    this.sizeTotal,
    this.currentPageBookmarked = false,
    this.currentPageBookmarkCfi,
    this.currentPageBookmarkId,
  });

  final ReaderStatus status;
  final String title;
  final Book? book;
  final SourceType sourceType;
  final bool pageProgressionRtl;
  final List<Highlight> highlights;
  final List<SourceBookmark> bookmarks;
  final List<ReaderTocItem> tocItems;

  /// Live chapter / page metrics surfaced by foliate-js on every page
  /// turn. Not persisted — they're recomputed on every reader open.
  final String? chapterTitle;
  final int? bookCurrentPage;
  final int? bookTotalPages;

  /// Position inside the current section — visual page within the active
  /// chapter for EPUB, comic page within the whole archive for CBZ
  /// (each image is its own section). For CBZ this is the only counter
  /// that meaningfully advances per page-turn; [bookCurrentPage] collapses
  /// comics into a handful of byte locations and is useless there.
  final int? chapterCurrentPage;
  final int? chapterTotalPages;

  /// Byte length of all linear sections in the open book — same quantity
  /// foliate-js uses to compute [bookCurrentPage] / [bookTotalPages].
  /// Constant per book; first `onRelocated` after open populates it.
  final int? sizeTotal;

  /// True when foliate-js reports that the visible page is already bookmarked.
  final bool currentPageBookmarked;
  final String? currentPageBookmarkCfi;
  final String? currentPageBookmarkId;

  String? get sourceId => book?.id;

  static const _absent = Object();

  ReaderState copyWith({
    ReaderStatus? status,
    String? title,
    Object? book = _absent,
    SourceType? sourceType,
    bool? pageProgressionRtl,
    List<Highlight>? highlights,
    List<SourceBookmark>? bookmarks,
    List<ReaderTocItem>? tocItems,
    Object? chapterTitle = _absent,
    Object? bookCurrentPage = _absent,
    Object? bookTotalPages = _absent,
    Object? chapterCurrentPage = _absent,
    Object? chapterTotalPages = _absent,
    Object? sizeTotal = _absent,
    bool? currentPageBookmarked,
    Object? currentPageBookmarkCfi = _absent,
    Object? currentPageBookmarkId = _absent,
  }) => ReaderState(
    status: status ?? this.status,
    title: title ?? this.title,
    book: book == _absent ? this.book : book as Book?,
    sourceType: sourceType ?? this.sourceType,
    pageProgressionRtl: pageProgressionRtl ?? this.pageProgressionRtl,
    highlights: highlights ?? this.highlights,
    bookmarks: bookmarks ?? this.bookmarks,
    tocItems: tocItems ?? this.tocItems,
    chapterTitle: chapterTitle == _absent
        ? this.chapterTitle
        : chapterTitle as String?,
    bookCurrentPage: bookCurrentPage == _absent
        ? this.bookCurrentPage
        : bookCurrentPage as int?,
    bookTotalPages: bookTotalPages == _absent
        ? this.bookTotalPages
        : bookTotalPages as int?,
    chapterCurrentPage: chapterCurrentPage == _absent
        ? this.chapterCurrentPage
        : chapterCurrentPage as int?,
    chapterTotalPages: chapterTotalPages == _absent
        ? this.chapterTotalPages
        : chapterTotalPages as int?,
    sizeTotal: sizeTotal == _absent ? this.sizeTotal : sizeTotal as int?,
    currentPageBookmarked: currentPageBookmarked ?? this.currentPageBookmarked,
    currentPageBookmarkCfi: currentPageBookmarkCfi == _absent
        ? this.currentPageBookmarkCfi
        : currentPageBookmarkCfi as String?,
    currentPageBookmarkId: currentPageBookmarkId == _absent
        ? this.currentPageBookmarkId
        : currentPageBookmarkId as String?,
  );

  @override
  List<Object?> get props => [
    status,
    title,
    book,
    sourceType,
    pageProgressionRtl,
    highlights,
    bookmarks,
    tocItems,
    chapterTitle,
    bookCurrentPage,
    bookTotalPages,
    chapterCurrentPage,
    chapterTotalPages,
    sizeTotal,
    currentPageBookmarked,
    currentPageBookmarkCfi,
    currentPageBookmarkId,
  ];
}
