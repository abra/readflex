/// Where the reader is, as the page surface reports it after every move:
/// the anchor to restore, the overall progress and the chapter around it.
class BookPosition {
  const BookPosition({
    required this.cfi,
    required this.fraction,
    this.chapterTitle,
    this.chapterCurrentPage,
    this.chapterTotalPages,
    this.bookCurrentPage,
    this.bookTotalPages,
    this.sizeTotal,
    this.relocationReason,
    this.pageProgressionRtl,
    this.atEnd = false,
    this.atStart = false,
    this.minutesLeft,
    this.bookmarkExists = false,
    this.bookmarkCfi,
    this.bookmarkId,
  });

  /// Position anchor: EPUB CFI for books or serialized article HTML position.
  final String cfi;

  /// Overall reading progress in [0, 1].
  final double fraction;

  final String? chapterTitle;
  final int? chapterCurrentPage;
  final int? chapterTotalPages;

  /// Zero-based, size-derived location (one per 1500 bytes of text), not a
  /// physical page. Chapter page counters may be more useful for
  /// fixed-layout sources.
  final int? bookCurrentPage;
  final int? bookTotalPages;

  /// Total byte size of all linear sections, the quantity [bookCurrentPage]
  /// and [bookTotalPages] count, so the slider can reproduce
  /// `floor(fraction × sizeTotal / 1500)` while the user drags. Constant per
  /// book; reported on every move for simplicity.
  final int? sizeTotal;

  /// Why the position moved. User-driven navigation is reported as `page`,
  /// `scroll`, or `snap`; programmatic jumps may omit it.
  final String? relocationReason;

  /// True when the publication's page progression is right-to-left, independent
  /// of text direction. Saved articles use continuous scrolling, not page turns.
  final bool? pageProgressionRtl;

  /// Whether forward navigation is at the end boundary. Progress pins to
  /// 100% there.
  final bool atEnd;

  /// Whether backward navigation is at the start boundary. Used by reader
  /// tap-zone availability; both this and [atEnd] can be false mid-document.
  final bool atStart;

  /// Estimated reading minutes left in the whole article (`minutesLeft`, 1200
  /// text characters per minute). Books send none: their progress row names
  /// the chapter. Null when the surface has no usable estimate.
  final double? minutesLeft;

  /// Current visible page has a bookmark annotation.
  final bool bookmarkExists;
  final String? bookmarkCfi;
  final String? bookmarkId;
}
