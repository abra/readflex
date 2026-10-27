part of 'reader_screen.dart';

/// Hosts the native comic engine (`package:vellum`) and translates its
/// events into the same reader bloc and cubit updates the WebView body
/// produces, so the chrome, drawers and context panel do not know which
/// engine draws the pages.
class _ReaderComicBody extends StatefulWidget {
  const _ReaderComicBody({
    super.key,
    required this.document,
    required this.readerTheme,
    required this.surface,
    required this.pageTurnStyle,
    this.onPositionChanged,
    this.onReady,
    this.onLoading,
  });

  final ReaderDocument document;
  final ReaderThemeData readerTheme;
  final ReaderComicSurface surface;
  final ReaderPageTurnStyle pageTurnStyle;
  final ValueChanged<BookPosition>? onPositionChanged;
  final VoidCallback? onReady;
  final VoidCallback? onLoading;

  @override
  State<_ReaderComicBody> createState() => _ReaderComicBodyState();
}

class _ReaderComicBodyState extends State<_ReaderComicBody> {
  ComicBook? _book;
  FixedPagesController? _controller;
  ReaderComicSession? _session;
  final _draft = ComicImageAreaDraft();
  int _openGeneration = 0;
  bool _ready = false;
  int? _reportedBookmarkedPage;

  List<Highlight>? _lastHighlightsRef;
  ReaderThemeData? _lastAreasTheme;
  List<ComicImageArea>? _cachedAreas;

  @override
  void initState() {
    super.initState();
    _applyDraftStyle();
    _notifyLoading();
    unawaited(_open());
  }

  /// The parent marks the surface unready in its own state; from inside a
  /// build that has to wait for the frame, as the WebView's callback does.
  void _notifyLoading() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_ready) widget.onLoading?.call();
    });
  }

  @override
  void didUpdateWidget(covariant _ReaderComicBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.readerTheme != widget.readerTheme) _applyDraftStyle();
    if (oldWidget.document.id != widget.document.id ||
        oldWidget.document.filePath != widget.document.filePath) {
      _ready = false;
      _notifyLoading();
      _closeBook();
      unawaited(_open());
    }
  }

  @override
  void dispose() {
    _closeBook();
    _draft.dispose();
    super.dispose();
  }

  void _applyDraftStyle() {
    _draft.setStyle(
      color: readerHighlightColor(HighlightColor.yellow, widget.readerTheme),
      opacity: readerHighlightOpacity(widget.readerTheme),
    );
  }

  Future<void> _open() async {
    final generation = ++_openGeneration;
    final document = widget.document;
    final ComicBook book;
    try {
      book = await ComicBook.open(
        document.filePath,
        pageOrderVersion: document.comicPageOrderVersion,
      );
    } catch (error, stackTrace) {
      if (!mounted || generation != _openGeneration) return;
      _debugTraceReader('_ReaderComicBody open failed: $error');
      context.read<ReaderBloc>().reportError(error, stackTrace);
      context.read<ReaderBloc>().add(
        ReaderWebViewFailed(
          sourceId: document.id,
          failure: const ReaderLoadFailure(ReaderLoadFailureKind.document),
        ),
      );
      return;
    }
    if (!mounted || generation != _openGeneration) {
      unawaited(book.close());
      return;
    }
    final bloc = context.read<ReaderBloc>();
    final controller = FixedPagesController(
      pageCount: book.pageCount,
      rtl: bloc.state.pageProgressionRtl,
      initialPage: _initialPage(document, book.pageCount),
    );
    final session = ReaderComicSession(
      controller: controller,
      book: book,
      draft: _draft,
      onToggleBookmark: _toggleBookmark,
    );
    controller.addListener(_onControllerChanged);
    widget.surface.attach(session);
    setState(() {
      _book = book;
      _controller = controller;
      _session = session;
    });
    bloc.add(ReaderTocUpdated(items: _tocItems(book)));
    _reportPosition();
  }

  void _closeBook() {
    _openGeneration++;
    final session = _session;
    if (session != null) widget.surface.detach(session);
    _controller?.removeListener(_onControllerChanged);
    _controller?.dispose();
    final book = _book;
    if (book != null) unawaited(book.close());
    _book = null;
    _controller = null;
    _session = null;
    _reportedBookmarkedPage = null;
  }

  /// The saved page: the CFI the WebView reader wrote, or the fraction for
  /// rows saved without one.
  static int _initialPage(ReaderDocument document, int pageCount) {
    final cfi = document.currentCfi;
    if (cfi != null) {
      final page = fakeCfiToIndex(cfi);
      if (page != null && page < pageCount) return page;
    }
    final fraction = document.readingProgress;
    if (fraction <= 0) return 0;
    if (fraction >= 1) return pageCount - 1;
    return math.min(pageCount - 1, (fraction * pageCount).floor());
  }

  /// One entry per page, named like the archive entry, as the WebView
  /// reader lists a comic's contents.
  static List<ReaderTocItem> _tocItems(ComicBook book) => [
    for (final page in book.pages)
      ReaderTocItem(
        label: page.name,
        href: page.name,
        level: 0,
        startPercentage: page.index / book.pageCount,
        startPage: page.index,
      ),
  ];

  void _onControllerChanged() {
    if (!mounted) return;
    _reportPosition();
  }

  SourceBookmark? _bookmarkOnPage(List<SourceBookmark> bookmarks, int page) {
    for (final bookmark in bookmarks) {
      if (bookmark.anchorSectionIndex == page ||
          fakeCfiToIndex(bookmark.cfi) == page) {
        return bookmark;
      }
    }
    return null;
  }

  BookPosition? _currentPosition() {
    final controller = _controller;
    final book = _book;
    if (controller == null || book == null) return null;
    final position = controller.position;
    final bookmark = _bookmarkOnPage(
      context.read<ReaderBloc>().state.bookmarks,
      position.page,
    );
    return BookPosition(
      cfi: position.cfi,
      fraction: position.fraction,
      chapterTitle: _chapterTitle(book.pages[position.page].name),
      chapterCurrentPage: position.chapterCurrentPage,
      chapterTotalPages: position.chapterTotalPages,
      bookCurrentPage: position.bookCurrentPage,
      bookTotalPages: position.bookTotalPages,
      sizeTotal: position.sizeTotal,
      relocationReason: switch (controller.lastRelocationReason) {
        PageRelocationReason.page => 'page',
        PageRelocationReason.navigation || null => null,
      },
      pageProgressionRtl: controller.rtl,
      atStart: controller.atStart,
      atEnd: controller.atEnd,
      bookmarkExists: bookmark != null,
      bookmarkCfi: bookmark?.cfi,
      bookmarkId: bookmark?.id,
    );
  }

  /// The WebView shell drops titles longer than this.
  static const _chapterTitleMaxLength = 512;

  static String? _chapterTitle(String label) {
    final title = label.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (title.isEmpty || title.length > _chapterTitleMaxLength) return null;
    return title;
  }

  void _reportPosition() {
    final position = _currentPosition();
    if (position == null) return;
    _reportedBookmarkedPage = position.bookmarkExists
        ? _controller!.page
        : null;
    _debugTraceReader(
      '_ReaderComicBody position '
      'page=${position.chapterCurrentPage}/${position.chapterTotalPages} '
      'progress=${position.fraction.toStringAsFixed(3)} '
      'reason=${position.relocationReason}',
    );
    context.read<ReaderBloc>().add(
      ReaderBookPositionUpdated.fromBookPosition(position),
    );
    widget.onPositionChanged?.call(position);
  }

  /// Bookmarks changed under the current page: the chrome's bookmark state
  /// follows the position report, as it does for the WebView.
  void _onBookmarksChanged(List<SourceBookmark> bookmarks) {
    final controller = _controller;
    if (controller == null) return;
    final bookmarked = _bookmarkOnPage(bookmarks, controller.page) != null;
    final reported = _reportedBookmarkedPage == controller.page;
    if (bookmarked != reported) _reportPosition();
  }

  void _toggleBookmark() {
    final controller = _controller;
    if (controller == null) return;
    final bloc = context.read<ReaderBloc>();
    final page = controller.page;
    final existing = _bookmarkOnPage(bloc.state.bookmarks, page);
    final position = controller.position;
    bloc.add(
      ReaderBookmarkChanged(
        remove: existing != null,
        id: existing?.id,
        cfi: existing?.cfi ?? position.cfi,
        content: 'Page ${page + 1} / ${controller.pageCount}',
        progress: position.fraction,
        anchorSectionIndex: page,
        anchorSectionPage: page,
      ),
    );
  }

  void _onPageShown(int page) {
    if (_ready || !mounted) return;
    _debugTraceReader('_ReaderComicBody first page shown page=$page');
    setState(() => _ready = true);
    widget.onReady?.call();
  }

  List<ComicImageArea> _areasFor(List<Highlight> highlights) {
    final cached = _cachedAreas;
    if (cached != null &&
        identical(highlights, _lastHighlightsRef) &&
        _lastAreasTheme == widget.readerTheme) {
      return cached;
    }
    _lastHighlightsRef = highlights;
    _lastAreasTheme = widget.readerTheme;
    // Oldest first: the newest area is drawn on top and answers presses.
    final ordered = [
      for (final highlight in highlights)
        if (highlight.isImageArea) highlight,
    ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return _cachedAreas = [
      for (final highlight in ordered)
        ComicImageArea(
          id: highlight.id,
          page: highlight.imageArea!.pageIndex,
          rect: Rect.fromLTWH(
            highlight.imageArea!.x,
            highlight.imageArea!.y,
            highlight.imageArea!.width,
            highlight.imageArea!.height,
          ),
          color: readerHighlightColor(highlight.color, widget.readerTheme),
        ),
    ];
  }

  static ReaderSelectionPosition? _selectionPosition(Rect? viewport) =>
      viewport == null
      ? null
      : ReaderSelectionPosition(
          left: viewport.left,
          top: viewport.top,
          right: viewport.right,
          bottom: viewport.bottom,
        );

  void _onDraftCommitted(int page, Rect rect, Rect? viewport) {
    final bloc = context.read<ReaderBloc>();
    final imageSelectionCubit = context.read<ReaderImageSelectionCubit>();
    // Long press has no native selection feedback; confirm the moment the
    // area appears, not on every later move or resize.
    if (!imageSelectionCubit.state.hasSelection) {
      unawaited(HapticFeedback.selectionClick());
    }
    context.read<ReaderHighlightFocusCubit>().clear();
    context.read<ReaderSelectionCubit>().deselect();
    context.read<ReaderUiCubit>().hideChrome();
    // Image-page chapter titles are archive file names; leave the saved
    // area without one so rows fall back to the localized page label.
    imageSelectionCubit.select(
      pageIndex: page,
      rect: ReaderImageAreaRect(
        x: rect.left,
        y: rect.top,
        width: rect.width,
        height: rect.height,
      ),
      position: _selectionPosition(viewport),
      progress: bloc.state.document?.readingProgress,
      chapterTitle: null,
    );
  }

  void _onDraftCancelled() {
    final imageSelectionCubit = context.read<ReaderImageSelectionCubit>();
    if (imageSelectionCubit.consumeProtectedClear()) return;
    context.read<ReaderSelectionCubit>().deselect();
    imageSelectionCubit.deselect();
  }

  void _onAreaPressed(ComicImageArea area, Rect? viewport) {
    context.read<ReaderUiCubit>().hideChrome();
    context.read<ReaderSelectionCubit>().deselect();
    context.read<ReaderImageSelectionCubit>().deselect();
    widget.surface.clearSelection();
    context.read<ReaderHighlightFocusCubit>().focus(
      ReaderHighlightTap(
        highlightId: area.id,
        position: _selectionPosition(viewport),
        contextText: '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final book = _book;
    final highlights = context.select<ReaderBloc, List<Highlight>>(
      (b) => b.state.highlights,
    );
    final bookmarks = context.select<ReaderBloc, List<SourceBookmark>>(
      (b) => b.state.bookmarks,
    );
    if (controller == null || book == null) {
      return ColoredBox(color: widget.readerTheme.backgroundColor);
    }
    // Bookmark rows change outside the engine; the position report carries
    // the page's bookmark state, so re-check after this frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onBookmarksChanged(bookmarks);
    });
    final areas = _areasFor(highlights);
    final surface = widget.surface;
    return FixedPagesView(
      pages: ComicPages(book),
      controller: controller,
      backgroundColor: widget.readerTheme.backgroundColor,
      axis: _nativePageAxis(widget.pageTurnStyle),
      onTap: (point) => _dispatchReaderTap(
        context,
        x: point.dx,
        y: point.dy,
        surface: surface,
        isComic: true,
        axis: _readerTapAxisForPageTurnStyle(widget.pageTurnStyle),
      ),
      onPageShown: _onPageShown,
      pageSemanticsLabel: (page, count) =>
          context.l10n.readerPageNumber(page + 1),
      failedPageSemanticsLabel: (page) =>
          context.l10n.readerThumbnailUnavailable,
      pageOverlayBuilder: (context, page, imageRect) => ComicImageAreaLayer(
        page: page,
        imageRect: imageRect,
        controller: controller,
        draft: _draft,
        areas: areas,
        onDraftCommitted: (rect, viewport) =>
            _onDraftCommitted(page, rect, viewport),
        onDraftCancelled: _onDraftCancelled,
        onAreaPressed: _onAreaPressed,
      ),
    );
  }
}
