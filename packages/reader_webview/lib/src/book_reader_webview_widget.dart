part of 'book_reader_webview.dart';

/// WebView-based book reader backed by foliate-js.
///
/// Loads foliate-js `index.html` from the local server's `/assets/foliate-js/`
/// route. foliate-js fetches the book file from `/book/<encoded-path>` and
/// renders it.
///
/// Communication:
///   JS → Flutter: `onReady`, `onRelocated`, `onSelectionEnd`,
///                  `onSelectionCleared`, `onAnnotationClick`, `onSetToc`,
///                  `onDocumentFeatures`, `onSearch`, `handleBookmark`
///   Flutter → JS: `goToCfi`, `goToHref`, `startSearch`, `cancelSearch`,
///                  `searchBook`, `clearSearch`, `nextPage`, `prevPage`,
///                  `changeStyle`, `addAnnotation`, `removeAnnotation`,
///                  `toggleBookmarkHere`
class BookReaderWebView extends StatefulWidget {
  const BookReaderWebView({
    required this.serverPort,
    required this.bookFilePath,
    this.initialCfi,
    this.initialProgress,
    this.isArticle = false,
    this.pageProgressionRtl = false,
    this.foliateStyle = const FoliateStyle(),
    this.highlights = const [],
    this.dictionaryAnchors = const [],
    this.bookmarks = const [],
    this.onReady,
    this.onPositionChanged,
    this.onTextSelected,
    this.onTextDeselected,
    this.onHighlightTapped,
    this.onDictionaryAnchorTapped,
    this.onTocChanged,
    this.onDocumentFeaturesChanged,
    this.onBookmarkChanged,
    this.onTapped,
    super.key,
  });

  /// Port of the local reader server.
  final int serverPort;

  /// Absolute path to the book file on disk.
  final String bookFilePath;

  /// CFI position to restore on load.
  final String? initialCfi;

  /// Fractional fallback used when exact CFI restore is unavailable or when
  /// the iOS crash-recovery path intentionally drops the saved CFI.
  final double? initialProgress;

  /// Whether the opened EPUB was generated from a saved web article.
  final bool isArticle;

  /// Initial page progression hint when source metadata is missing or wrong.
  final bool pageProgressionRtl;

  /// Book reader appearance passed to foliate-js via URL params.
  final FoliateStyle foliateStyle;

  /// Highlights to render as annotations on load.
  final List<ReaderHighlight> highlights;

  /// Dictionary entries to render as source-text underlines on load.
  final List<ReaderDictionaryAnchor> dictionaryAnchors;

  /// Bookmarks to render as foliate-js bookmark annotations on load.
  final List<ReaderBookmark> bookmarks;

  /// Fires once when foliate-js has loaded the book and is ready.
  final VoidCallback? onReady;

  /// Fires on page turn with the new position.
  final void Function(BookPosition position)? onPositionChanged;

  /// Fires when the user selects text.
  final void Function(ReaderSelection selection)? onTextSelected;

  /// Fires when the user clears the selection.
  final VoidCallback? onTextDeselected;

  /// Fires when the user taps an existing highlight annotation.
  final void Function(String highlightId)? onHighlightTapped;

  /// Fires when the user taps an existing dictionary underline annotation.
  final void Function(ReaderDictionaryAnchorTap tap)? onDictionaryAnchorTapped;

  /// Fires when foliate-js has parsed the book's table of contents.
  final void Function(List<ReaderTocItem> items)? onTocChanged;

  /// Fires when the runtime has detected optional document capabilities.
  final void Function(ReaderDocumentFeatures features)?
  onDocumentFeaturesChanged;

  /// Fires when foliate-js requests adding/removing a bookmark.
  final void Function(ReaderBookmarkChange change)? onBookmarkChanged;

  /// Fires when the user taps empty reader space (no selection, no link).
  /// Coordinates are normalized to [0, 1] over the viewport.
  final void Function(double x, double y)? onTapped;

  @override
  State<BookReaderWebView> createState() => BookReaderWebViewState();
}
