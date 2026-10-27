part of 'reader_screen.dart';

/// Hosts the native PDF engine (`package:vellum`) and translates its
/// events into the same reader bloc and cubit updates the WebView body
/// produces: pages, position, bookmarks, outline, text selection, saved
/// highlights, search marks, margin crops and page colours.
class _ReaderPdfBody extends StatefulWidget {
  const _ReaderPdfBody({
    super.key,
    required this.document,
    required this.readerTheme,
    required this.surface,
    required this.trimPageMargins,
    required this.pageColors,
    required this.pageTurnStyle,
    this.onPositionChanged,
    this.onReady,
    this.onLoading,
  });

  final ReaderDocument document;
  final ReaderThemeData readerTheme;
  final ReaderPdfSurface surface;
  final bool trimPageMargins;
  final ReaderPageColors pageColors;
  final ReaderPageTurnStyle pageTurnStyle;
  final ValueChanged<BookPosition>? onPositionChanged;
  final VoidCallback? onReady;
  final VoidCallback? onLoading;

  @override
  State<_ReaderPdfBody> createState() => _ReaderPdfBodyState();
}

class _ReaderPdfBodyState extends State<_ReaderPdfBody> {
  PdfBook? _book;
  FixedPagesController? _controller;
  PdfTextLayerCache? _layers;
  ReaderPdfSession? _session;
  final _selection = PdfTextSelection();
  int _openGeneration = 0;
  bool _ready = false;
  int? _reportedBookmarkedPage;
  bool _searchableTextReported = false;

  /// Outline titles by the page they open, for the chrome's chapter line.
  Map<int, String> _outlineTitles = const {};

  /// Margin crops as fractions of the page, null for a page kept whole;
  /// absent while not yet measured. Measured for the box in [_cropBox].
  final _crops = <int, Rect?>{};
  final _cropRequests = <int>{};
  Size? _cropBox;

  ({int page, PdfTextRange range})? _searchMark;

  List<Highlight>? _lastHighlightsRef;
  ReaderThemeData? _lastHighlightsTheme;
  final _resolvedHighlights =
      <int, ({PdfTextLayer layer, List<PdfTextHighlight> items})>{};

  @override
  void initState() {
    super.initState();
    _notifyLoading();
    unawaited(_open());
  }

  void _notifyLoading() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_ready) widget.onLoading?.call();
    });
  }

  @override
  void didUpdateWidget(covariant _ReaderPdfBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document.id != widget.document.id ||
        oldWidget.document.filePath != widget.document.filePath) {
      _ready = false;
      _notifyLoading();
      _closeBook();
      unawaited(_open());
    }
    if (oldWidget.trimPageMargins != widget.trimPageMargins) {
      _requestCrops();
    }
  }

  @override
  void dispose() {
    _closeBook();
    _selection.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    final generation = ++_openGeneration;
    final document = widget.document;
    final PdfBook book;
    try {
      book = await PdfBook.open(document.filePath);
    } catch (error, stackTrace) {
      if (!mounted || generation != _openGeneration) return;
      _debugTraceReader('_ReaderPdfBody open failed: $error');
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
      rtl: false,
      initialPage: _nativeInitialPage(document, book.pageCount),
    );
    final layers = PdfTextLayerCache(book);
    final session = ReaderPdfSession(
      controller: controller,
      book: book,
      layers: layers,
      selection: _selection,
      onToggleBookmark: _toggleBookmark,
      onSearchMark: _setSearchMark,
    );
    controller.addListener(_onControllerChanged);
    layers.addListener(_onLayersChanged);
    widget.surface.attach(session);
    setState(() {
      _book = book;
      _controller = controller;
      _layers = layers;
      _session = session;
      _outlineTitles = _titlesByPage(book.outline);
      _crops.clear();
      _cropRequests.clear();
      _resolvedHighlights.clear();
      _searchMark = null;
      _searchableTextReported = false;
    });
    bloc.add(ReaderTocUpdated(items: _tocItems(book)));
    bloc.add(
      ReaderDocumentFeaturesUpdated(
        features: ReaderDocumentFeatures(
          format: 'pdf',
          hasTableOfContents: book.outline.isNotEmpty,
          pageCount: book.pageCount,
        ),
      ),
    );
    _reportPosition();
    _loadVisibleLayers();
  }

  void _closeBook() {
    _openGeneration++;
    final session = _session;
    if (session != null) widget.surface.detach(session);
    _controller?.removeListener(_onControllerChanged);
    _controller?.dispose();
    _layers?.removeListener(_onLayersChanged);
    _layers?.dispose();
    final book = _book;
    if (book != null) unawaited(book.close());
    _book = null;
    _controller = null;
    _layers = null;
    _session = null;
    _reportedBookmarkedPage = null;
    _selection.clear();
  }

  // Outline.

  /// Entries flattened in order with their depth; an entry without a page
  /// keeps an empty href, which the surface ignores.
  static List<ReaderTocItem> _tocItems(PdfBook book) {
    final items = <ReaderTocItem>[];
    void add(List<PdfOutlineEntry> entries, int level) {
      for (final entry in entries) {
        final page = entry.pageIndex;
        items.add(
          ReaderTocItem(
            label: entry.title,
            href: page == null ? '' : fakeCfiFromIndex(page),
            level: level,
            startPercentage: page == null ? null : page / book.pageCount,
            startPage: page,
          ),
        );
        add(entry.children, level + 1);
      }
    }

    add(book.outline, 0);
    return items;
  }

  /// The first outline entry that opens each page, as the WebView matched
  /// a page's chapter by its exact TOC href.
  static Map<int, String> _titlesByPage(List<PdfOutlineEntry> outline) {
    final titles = <int, String>{};
    void walk(List<PdfOutlineEntry> entries) {
      for (final entry in entries) {
        final page = entry.pageIndex;
        if (page != null && !titles.containsKey(page)) {
          final title = _nativeChapterTitle(entry.title);
          if (title != null) titles[page] = title;
        }
        walk(entry.children);
      }
    }

    walk(outline);
    return titles;
  }

  // Position and bookmarks.

  void _onControllerChanged() {
    if (!mounted) return;
    _reportPosition();
    _loadVisibleLayers();
    _requestCrops();
  }

  BookPosition? _currentPosition() {
    final controller = _controller;
    if (controller == null) return null;
    final position = controller.position;
    final bookmark = _nativeBookmarkOnPage(
      context.read<ReaderBloc>().state.bookmarks,
      position.page,
    );
    return BookPosition(
      cfi: position.cfi,
      fraction: position.fraction,
      chapterTitle: _outlineTitles[position.page],
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

  void _reportPosition() {
    final position = _currentPosition();
    if (position == null) return;
    _reportedBookmarkedPage = position.bookmarkExists
        ? _controller!.page
        : null;
    _debugTraceReader(
      '_ReaderPdfBody position '
      'page=${position.chapterCurrentPage}/${position.chapterTotalPages} '
      'progress=${position.fraction.toStringAsFixed(3)} '
      'reason=${position.relocationReason}',
    );
    context.read<ReaderBloc>().add(
      ReaderBookPositionUpdated.fromBookPosition(position),
    );
    widget.onPositionChanged?.call(position);
  }

  void _onBookmarksChanged(List<SourceBookmark> bookmarks) {
    final controller = _controller;
    if (controller == null) return;
    final bookmarked =
        _nativeBookmarkOnPage(bookmarks, controller.page) != null;
    final reported = _reportedBookmarkedPage == controller.page;
    if (bookmarked != reported) _reportPosition();
  }

  void _toggleBookmark() {
    final controller = _controller;
    if (controller == null) return;
    final bloc = context.read<ReaderBloc>();
    final page = controller.page;
    final existing = _nativeBookmarkOnPage(bloc.state.bookmarks, page);
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
    _debugTraceReader('_ReaderPdfBody first page shown page=$page');
    setState(() => _ready = true);
    widget.onReady?.call();
  }

  // Text layers.

  /// Loads the text of the pages on screen and their neighbours, so
  /// selection and highlights are ready when the reader gets there.
  void _loadVisibleLayers() {
    final controller = _controller;
    final layers = _layers;
    if (controller == null || layers == null) return;
    for (final page in [
      ...controller.visiblePages,
      ...controller.pagesToPrefetch,
    ]) {
      if (layers.peek(page) != null) continue;
      // A page whose text fails to load stays without selection; the
      // next visit tries again.
      unawaited(layers.load(page).then((_) {}, onError: (_) {}));
    }
  }

  void _onLayersChanged() {
    if (!mounted) return;
    final layers = _layers;
    if (layers != null &&
        !_searchableTextReported &&
        layers.loadedLayers.any((layer) => !layer.isEmpty)) {
      _searchableTextReported = true;
      context.read<ReaderBloc>().add(
        ReaderDocumentFeaturesUpdated(
          features: ReaderDocumentFeatures(
            format: 'pdf',
            hasTableOfContents: _book?.outline.isNotEmpty,
            hasSearchableText: true,
            pageCount: _book?.pageCount,
          ),
        ),
      );
    }
    setState(() {});
  }

  // Margin crops.

  /// Measures the pages on screen for [FixedPagesView.visibleRectOf] when
  /// trimming is on; a box change throws the measurements away.
  void _requestCrops() {
    final book = _book;
    final controller = _controller;
    final box = _cropBox;
    if (!widget.trimPageMargins ||
        book == null ||
        controller == null ||
        box == null) {
      return;
    }
    for (final page in [
      ...controller.visiblePages,
      ...controller.pagesToPrefetch,
    ]) {
      if (_crops.containsKey(page) || !_cropRequests.add(page)) continue;
      final generation = _openGeneration;
      unawaited(
        detectPdfPageContent(book, page).then(
          (content) {
            if (!mounted || generation != _openGeneration) return;
            _cropRequests.remove(page);
            final info = book.pages[page];
            final crop = contentCrop(
              content: content,
              width: info.width,
              height: info.height,
              availableWidth: box.width,
              availableHeight: box.height,
            );
            setState(() {
              _crops[page] = crop == null
                  ? null
                  : Rect.fromLTRB(
                      crop.left / info.width,
                      crop.top / info.height,
                      crop.right / info.width,
                      crop.bottom / info.height,
                    );
            });
          },
          onError: (_) {
            if (mounted) _cropRequests.remove(page);
          },
        ),
      );
    }
  }

  /// The box one page is fitted into: the view, or half of it in a spread.
  void _updateCropBox(Size viewSize) {
    final controller = _controller;
    final box = controller != null && !controller.singlePage
        ? Size(viewSize.width / 2, viewSize.height)
        : viewSize;
    if (box == _cropBox) return;
    _cropBox = box;
    _crops.clear();
    _cropRequests.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _requestCrops();
    });
  }

  Rect? _visibleRectOf(int page) =>
      widget.trimPageMargins ? _crops[page] : null;

  // Selection, highlights, search.

  void _onSelectionChanged(int page, PdfTextRange range, Rect? viewport) {
    final layer = _layers?.peek(page);
    final bloc = context.read<ReaderBloc>();
    final selectionCubit = context.read<ReaderSelectionCubit>();
    if (layer == null) return;
    if (!selectionCubit.state.hasSelection) {
      unawaited(HapticFeedback.selectionClick());
    }
    context.read<ReaderHighlightFocusCubit>().clear();
    context.read<ReaderImageSelectionCubit>().deselect();
    context.read<ReaderUiCubit>().hideChrome();
    final selection = readerSelectionFromLayer(
      layer,
      range,
      position: _nativeSelectionPosition(viewport),
    );
    selectionCubit.select(
      text: selection.text,
      normalizedText: selection.normalizedText,
      selectionKind: selection.selectionKind,
      contextText: selection.contextText,
      markedContextText: selection.markedContextText,
      normalizedMarkedContextText: selection.normalizedMarkedContextText,
      cfiRange: selection.cfiRange,
      normalizedCfiRange: selection.normalizedCfiRange,
      position: selection.position,
      progress: bloc.state.document?.readingProgress,
      chapterTitle: _outlineTitles[page],
    );
  }

  void _onSelectionCleared() {
    context.read<ReaderSelectionCubit>().deselect();
  }

  void _onHighlightPressed(PdfTextHighlight highlight, Rect? viewport) {
    context.read<ReaderUiCubit>().hideChrome();
    context.read<ReaderSelectionCubit>().deselect();
    context.read<ReaderImageSelectionCubit>().deselect();
    widget.surface.clearSelection();
    final layer = _layers?.peek(highlight.page);
    context.read<ReaderHighlightFocusCubit>().focus(
      ReaderHighlightTap(
        highlightId: highlight.id,
        position: _nativeSelectionPosition(viewport),
        contextText: layer?.contextOf(highlight.range).contextText ?? '',
      ),
    );
  }

  void _setSearchMark(int page, PdfTextRange? range) {
    if (!mounted) return;
    setState(() {
      _searchMark = range == null ? null : (page: page, range: range);
    });
  }

  /// Saved text highlights of [page] placed on its text layer; resolved
  /// once per highlight list, layer and theme.
  List<PdfTextHighlight> _highlightsFor(
    int page,
    PdfTextLayer? layer,
    List<Highlight> highlights,
  ) {
    if (layer == null) return const [];
    if (!identical(highlights, _lastHighlightsRef) ||
        _lastHighlightsTheme != widget.readerTheme) {
      _lastHighlightsRef = highlights;
      _lastHighlightsTheme = widget.readerTheme;
      _resolvedHighlights.clear();
    }
    final cached = _resolvedHighlights[page];
    if (cached != null && identical(cached.layer, layer)) return cached.items;
    final opacity = readerHighlightOpacity(widget.readerTheme);
    final items = <PdfTextHighlight>[];
    for (final highlight in highlights) {
      final cfiRange = highlight.cfiRange;
      if (highlight.isImageArea || cfiRange == null) continue;
      if (fakeCfiToIndex(cfiRange) != page) continue;
      final range = resolvePdfTextAnchor(
        layer,
        text: highlight.text,
        cfiRange: cfiRange,
      );
      if (range == null) continue;
      items.add(
        PdfTextHighlight(
          id: highlight.id,
          page: page,
          range: range,
          color: readerHighlightColor(
            highlight.color,
            widget.readerTheme,
          ).withValues(alpha: opacity),
        ),
      );
    }
    _resolvedHighlights[page] = (layer: layer, items: items);
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final book = _book;
    final layers = _layers;
    final highlights = context.select<ReaderBloc, List<Highlight>>(
      (b) => b.state.highlights,
    );
    final bookmarks = context.select<ReaderBloc, List<SourceBookmark>>(
      (b) => b.state.bookmarks,
    );
    if (controller == null || book == null || layers == null) {
      return ColoredBox(color: widget.readerTheme.backgroundColor);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onBookmarksChanged(bookmarks);
    });
    final surface = widget.surface;
    final theme = widget.readerTheme;
    final pageColors = pageColorsFor(
      themed: widget.pageColors == ReaderPageColors.theme,
      background: theme.backgroundColor,
      foreground: theme.primaryTextColor,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        _updateCropBox(constraints.biggest);
        return FixedPagesView(
          pages: PdfPages(book),
          controller: controller,
          backgroundColor: theme.backgroundColor,
          pageColors: pageColors,
          axis: _nativePageAxis(widget.pageTurnStyle),
          visibleRectOf: widget.trimPageMargins ? _visibleRectOf : null,
          onTap: (point) => _dispatchReaderTap(
            context,
            x: point.dx,
            y: point.dy,
            surface: surface,
            isComic: false,
            axis: _readerTapAxisForPageTurnStyle(widget.pageTurnStyle),
          ),
          onPageShown: _onPageShown,
          pageSemanticsLabel: (page, count) =>
              context.l10n.readerPageNumber(page + 1),
          failedPageSemanticsLabel: (page) =>
              context.l10n.readerThumbnailUnavailable,
          pageOverlayBuilder: (context, page, imageRect) {
            final layer = layers.peek(page);
            final info = book.pages[page];
            final mark = _searchMark;
            return PdfTextOverlay(
              page: page,
              imageRect: imageRect,
              pageWidth: info.width,
              pageHeight: info.height,
              controller: controller,
              selection: _selection,
              layer: layer,
              highlights: _highlightsFor(page, layer, highlights),
              searchMark: mark != null && mark.page == page ? mark.range : null,
              onSelectionChanged: (range, viewport) =>
                  _onSelectionChanged(page, range, viewport),
              onSelectionCleared: _onSelectionCleared,
              onHighlightPressed: _onHighlightPressed,
            );
          },
        );
      },
    );
  }
}

/// The saved page of a native fixed-layout book: the CFI either reader
/// wrote, or the fraction for rows saved without one.
int _nativeInitialPage(ReaderDocument document, int pageCount) {
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

SourceBookmark? _nativeBookmarkOnPage(
  List<SourceBookmark> bookmarks,
  int page,
) {
  for (final bookmark in bookmarks) {
    if (bookmark.anchorSectionIndex == page ||
        fakeCfiToIndex(bookmark.cfi) == page) {
      return bookmark;
    }
  }
  return null;
}

/// The WebView shell drops titles longer than this.
const _nativeChapterTitleMaxLength = 512;

String? _nativeChapterTitle(String label) {
  final title = label.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (title.isEmpty || title.length > _nativeChapterTitleMaxLength) return null;
  return title;
}

ReaderSelectionPosition? _nativeSelectionPosition(Rect? viewport) =>
    viewport == null
    ? null
    : ReaderSelectionPosition(
        left: viewport.left,
        top: viewport.top,
        right: viewport.right,
        bottom: viewport.bottom,
      );
