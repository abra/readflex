part of 'reader_screen.dart';

/// Hosts the text engine (`package:vellum`) for EPUB, FB2 and MOBI books
/// and translates its events into the reader bloc and cubit updates every
/// page body produces: position, table of contents, bookmarks,
/// text selection with its context, saved highlights, search marks,
/// links and notes.
class _ReaderTextBody extends StatefulWidget {
  const _ReaderTextBody({
    super.key,
    required this.document,
    required this.readerTheme,
    required this.appearance,
    required this.surface,
    this.searchOverlayBottomFraction = 0,
    this.onPositionChanged,
    this.onReady,
    this.onLoading,
    this.onExternalLink,
  });

  final ReaderDocument document;
  final ReaderThemeData readerTheme;
  final ReaderAppearancePreferences appearance;
  final ReaderTextSurface surface;

  /// The share of the page the search bar covers, where the active hit
  /// is marked when it hides there.
  final double searchOverlayBottomFraction;
  final ValueChanged<BookPosition>? onPositionChanged;
  final VoidCallback? onReady;
  final VoidCallback? onLoading;
  final ValueChanged<String>? onExternalLink;

  @override
  State<_ReaderTextBody> createState() => _ReaderTextBodyState();
}

class _ReaderTextBodyState extends State<_ReaderTextBody> {
  Object? _book;
  TextBookSource? _source;
  TextPagesController? _controller;
  BookImageCache? _images;
  ReaderTextSession? _session;
  int _openGeneration = 0;
  bool _ready = false;
  TextPagePosition? _reportedPosition;
  bool? _reportedBookmark;

  /// What text actions get for the selection on screen.
  TextSelectionDetails? _selectionDetails;
  ReaderSelectionPosition? _selectionPosition;

  /// The highlight tint the reader previews on the selection.
  ({String cfi, Color color})? _preview;
  String? _searchMarkCfi;

  /// Where the active search hit is drawn in the view.
  final _activeHitRects = ValueNotifier<List<Rect>>(const []);

  /// Saved highlights placed in each section's document, for the list,
  /// theme and layout they were placed for.
  List<Highlight>? _lastHighlightsRef;
  ReaderThemeData? _lastHighlightsTheme;
  final _placedHighlights =
      <int, ({TextSectionLayout layout, List<TextHighlight> items})>{};

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    _applyAppearance();
  }

  @override
  void didUpdateWidget(covariant _ReaderTextBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document.id != widget.document.id ||
        oldWidget.document.filePath != widget.document.filePath) {
      _ready = false;
      _notifyLoading();
      _closeBook();
      unawaited(_open());
      return;
    }
    if (oldWidget.appearance != widget.appearance ||
        oldWidget.readerTheme != widget.readerTheme) {
      _applyAppearance();
    }
  }

  @override
  void dispose() {
    _closeBook();
    _activeHitRects.dispose();
    super.dispose();
  }

  // Opening.

  Future<void> _open() async {
    final generation = ++_openGeneration;
    final document = widget.document;
    final TextBookSource source;
    final Object book;
    try {
      book = await _openTextBook(document);
      source = textBookSourceOf(book);
    } catch (error, stackTrace) {
      if (!mounted || generation != _openGeneration) return;
      _debugTraceReader('_ReaderTextBody open failed: $error');
      context.read<ReaderBloc>().add(
        ReaderSurfaceFailed(
          sourceId: document.id,
          error: error,
          stackTrace: stackTrace,
        ),
      );
      return;
    }
    if (!mounted || generation != _openGeneration) {
      unawaited(source.close());
      return;
    }
    // WebKit's line boxes need the reader's fonts' ink.
    _fontInk = _webKitLines ? await readerFontInk() : const {};
    if (!mounted || generation != _openGeneration) {
      unawaited(source.close());
      return;
    }
    final images = BookImageCache(read: source.readImage);
    final controller = TextPagesController(
      source: source,
      style: _bookStyle(),
      fonts: _bookFonts(),
      images: images,
      settings: _pageSettings(),
      rtl: source.rtl,
      initialCfi: document.currentCfi,
      initialFraction: document.currentCfi == null
          ? document.readingProgress
          : null,
    );
    final session = ReaderTextSession(
      controller: controller,
      source: source,
      onToggleBookmark: _toggleBookmark,
      onSearchMark: _setSearchMark,
      onSelectionPreview: _setPreview,
      currentSelection: _currentSelection,
      chapterTitleOf: _chapterTitleOf,
      locale: document.language ?? source.language ?? 'en',
    );
    controller.addListener(_onControllerChanged);
    widget.surface.attach(session);
    setState(() {
      _book = book;
      _source = source;
      _images = images;
      _controller = controller;
      _session = session;
      _placedHighlights.clear();
    });
    final bloc = context.read<ReaderBloc>();
    bloc.add(ReaderTocUpdated(items: _tocItems(source)));
    bloc.add(
      ReaderDocumentFeaturesUpdated(
        features: ReaderDocumentFeatures(
          format: document.format?.name,
          hasTableOfContents: source.toc?.isNotEmpty ?? false,
          hasSearchableText: true,
        ),
      ),
    );
  }

  void _closeBook() {
    _openGeneration++;
    final session = _session;
    if (session != null) widget.surface.detach(session);
    _controller?.removeListener(_onControllerChanged);
    _controller?.dispose();
    _images?.dispose();
    final source = _source;
    if (source != null) unawaited(source.close());
    _book = null;
    _source = null;
    _images = null;
    _controller = null;
    _session = null;
    _reportedPosition = null;
    _reportedBookmark = null;
    _selectionDetails = null;
  }

  // Appearance.

  void _applyAppearance() {
    final controller = _controller;
    if (controller == null) return;
    controller
      ..style = _bookStyle()
      ..fonts = _bookFonts()
      ..settings = _pageSettings();
  }

  BookStyle _bookStyle() => _vellumBookStyle(
    context,
    appearance: widget.appearance,
    theme: widget.readerTheme,
  );

  /// CSS generics resolve to the app's bundled faces; symbols come from the
  /// symbol font.
  BookFonts _bookFonts() => _vellumBookFonts(_fontInk);

  /// The reader's fonts' ink, for WebKit's line boxes.
  Map<String, FontInk> _fontInk = const {};

  TextPageSettings _pageSettings() {
    final appearance = widget.appearance;
    final layout = BookLayoutPreset.fromId(appearance.layoutId).data;
    final padding = MediaQuery.paddingOf(context);
    final columns = readerTextColumns(
      wideWindow: AppWindowSize.isWide(context),
      fixedLayout: false,
      columns: appearance.columns,
    );
    final em = columns.maxLineWidthEm;
    final fontSize = layout.fontSize * _vellumDeviceFontScale(context);
    return TextPageSettings(
      sideMarginPercent: appearance.sideMargin,
      topMargin: layout.topMargin,
      bottomMargin: layout.bottomMargin,
      maxColumnCount: columns.maxColumnCount,
      // The longest line in ems of the prose size.
      measure: em == null
          ? null
          : (em * 16 * fontSize * appearance.textScale).roundToDouble(),
      safeInlineInset: math.max(padding.left, padding.right),
    );
  }

  // Table of contents.

  /// Entries flattened in order with their depth: level 1 at the top, as
  /// the drawer indents them.
  static List<ReaderTocItem> _tocItems(TextBookSource source) {
    final items = <ReaderTocItem>[];
    void add(List<BookNavItem> entries, int level) {
      for (final entry in entries) {
        items.add(
          ReaderTocItem(
            label: entry.label,
            href: entry.href ?? '',
            level: level,
          ),
        );
        final children = entry.subitems;
        if (children != null) add(children, level + 1);
      }
    }

    add(source.toc ?? const [], 1);
    return items;
  }

  String? _chapterTitleOf(int section) {
    final label = _controller?.tocItemOf(section)?.label;
    return label == null ? null : _nativeChapterTitle(label);
  }

  // Position and bookmarks.

  void _onControllerChanged() {
    if (!mounted) return;
    final controller = _controller;
    final error = controller?.error;
    if (controller != null && controller.position == null && error != null) {
      context.read<ReaderBloc>().add(
        ReaderSurfaceFailed(sourceId: widget.document.id, error: error),
      );
      return;
    }
    final position = controller?.position;
    if (position != null && !identical(position, _reportedPosition)) {
      _reportPosition();
      if (!_ready) {
        _ready = true;
        widget.onReady?.call();
      }
    }
    _rebuild();
  }

  /// A rebuild, after the frame when the change comes during one (a
  /// selection cleared while the screen is torn down).
  void _rebuild() {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  bool get _atStart {
    final controller = _controller;
    final source = _source;
    final position = controller?.position;
    if (source == null || position == null) return false;
    if (position.spread > 0) return false;
    for (var i = 0; i < position.section; i++) {
      if (source.isLinear(i)) return false;
    }
    return true;
  }

  bool get _atEnd {
    final controller = _controller;
    final source = _source;
    final position = controller?.position;
    if (source == null || position == null) return false;
    final spreads = position.spreadCount;
    if (spreads == null || position.spread < spreads - 1) return false;
    for (var i = position.section + 1; i < source.sectionCount; i++) {
      if (source.isLinear(i)) return false;
    }
    return true;
  }

  BookPosition? _currentPosition() {
    final position = _controller?.position;
    if (position == null) return null;
    final bookmark = _bookmarkOnScreen(
      context.read<ReaderBloc>().state.bookmarks,
    );
    final progress = position.progress;
    final atEnd = _atEnd;
    return BookPosition(
      cfi: position.cfi,
      fraction: atEnd ? 1 : position.fraction,
      chapterTitle: position.tocItem == null
          ? null
          : _nativeChapterTitle(position.tocItem!.label),
      chapterCurrentPage: position.spread + 1,
      chapterTotalPages: position.spreadCount,
      bookCurrentPage: progress.location,
      bookTotalPages: progress.locationCount,
      sizeTotal: _sizeTotal(),
      relocationReason: switch (position.reason) {
        TextRelocationReason.page => 'page',
        TextRelocationReason.navigation || TextRelocationReason.layout => null,
      },
      pageProgressionRtl: _source?.rtl ?? false,
      atStart: _atStart,
      atEnd: atEnd,
      bookmarkExists: bookmark != null,
      bookmarkCfi: bookmark?.cfi,
      bookmarkId: bookmark?.id,
    );
  }

  int? _sizeTotal() {
    final source = _source;
    if (source == null) return null;
    var total = 0;
    for (var i = 0; i < source.sectionCount; i++) {
      if (source.isLinear(i)) total += source.sectionSize(i);
    }
    return total;
  }

  void _reportPosition() {
    final position = _currentPosition();
    if (position == null) return;
    _reportedPosition = _controller?.position;
    _reportedBookmark = position.bookmarkExists;
    _debugTraceReader(
      '_ReaderTextBody position '
      'page=${position.chapterCurrentPage}/${position.chapterTotalPages} '
      'progress=${position.fraction.toStringAsFixed(3)} '
      'reason=${position.relocationReason}',
    );
    context.read<ReaderBloc>().add(
      ReaderBookPositionUpdated.fromBookPosition(position),
    );
    widget.onPositionChanged?.call(position);
  }

  /// The visible range of the spread on screen, as document points.
  (TextSectionLayout, TextPoint, TextPoint)? _visibleRange() {
    final spread = _controller?.spreadAt(0);
    if (spread == null || spread.pages.isEmpty) return null;
    final locator = spread.layout.locator;
    final start = locator.pointAt(spread.pages.first.top);
    final end = locator.endPointAt(spread.pages.last.bottom);
    if (start == null || end == null) return null;
    return (spread.layout, start, end);
  }

  /// The bookmark whose start is on screen: what the chrome's bookmark
  /// button and the page's ribbon show.
  SourceBookmark? _bookmarkOnScreen(List<SourceBookmark> bookmarks) {
    final visible = _visibleRange();
    final source = _source;
    if (visible == null || source == null) return null;
    final (layout, start, end) = visible;
    final doc = layout.prepared.document;
    for (final bookmark in bookmarks) {
      if (source.sectionOfCfi(bookmark.cfi) != layout.index) continue;
      final parsed = Cfi.tryParse(bookmark.cfi);
      if (parsed == null) continue;
      final TextPoint point;
      try {
        point = doc.textPointOf(cfiToRange(doc, parsed).start);
      } on CfiResolveException {
        continue;
      }
      if (doc.comparePoints(point, start) >= 0 &&
          doc.comparePoints(point, end) < 0) {
        return bookmark;
      }
    }
    return null;
  }

  void _onBookmarksChanged(List<SourceBookmark> bookmarks) {
    if (_controller?.position == null) return;
    final bookmarked = _bookmarkOnScreen(bookmarks) != null;
    if (bookmarked != _reportedBookmark) _reportPosition();
  }

  /// Bookmarks the first word on screen with a precise range CFI (anchor
  /// version 2): it opens on that word in any layout.
  void _toggleBookmark() {
    final controller = _controller;
    final position = controller?.position;
    final visible = _visibleRange();
    if (controller == null || position == null || visible == null) return;
    final bloc = context.read<ReaderBloc>();
    final existing = _bookmarkOnScreen(bloc.state.bookmarks);
    if (existing != null) {
      bloc.add(
        ReaderBookmarkChanged(
          remove: true,
          id: existing.id,
          cfi: existing.cfi,
          content: existing.content,
          progress: position.fraction,
        ),
      );
      return;
    }
    final (layout, start, end) = visible;
    final doc = layout.prepared.document;
    final word = _firstWord(doc, start, end);
    final sectionCfi = layout.sectionCfi;
    final cfi = word == null
        ? position.cfi
        : joinCfiIndirections([
            sectionCfi,
            cfiFromRange(doc.cfiRangeOf(word)).toInnerString(),
          ]);
    var content = doc.textOfRange(TextPointRange(start, end)).trim();
    content = content.replaceAll(RegExp(r'\s+'), ' ');
    if (content.length > 200) content = '${content.substring(0, 200)}...';
    bloc.add(
      ReaderBookmarkChanged(
        remove: false,
        cfi: cfi,
        content: content,
        progress: position.fraction,
        anchorExact: word == null ? null : doc.textOfRange(word),
        anchorSectionIndex: layout.index,
        anchorSectionPage: position.spread,
        anchorVersion: word == null ? null : 2,
      ),
    );
  }

  /// The first word from [start] before [end], within its text node.
  static TextPointRange? _firstWord(
    ContentDocument doc,
    TextPoint start,
    TextPoint end,
  ) {
    TextPointRange? found;
    doc.forEachTextIn(TextPointRange(start, end), (node, from, to) {
      if (found != null) return;
      final text = doc.textOf(node);
      var i = from;
      while (i < to && text.codeUnitAt(i) <= 0x20) {
        i++;
      }
      if (i >= to) return;
      var j = i;
      while (j < to && text.codeUnitAt(j) > 0x20) {
        j++;
      }
      found = TextPointRange(TextPoint(node, i), TextPoint(node, j));
    });
    return found;
  }

  // Selection.

  void _onSelectionChanged(TextPagesSelection? selection) {
    _selectionDetails = null;
    final selectionCubit = context.read<ReaderSelectionCubit>();
    if (selection == null) {
      _selectionPosition = null;
      selectionCubit.deselect();
      return;
    }
    if (!selectionCubit.state.hasSelection) {
      unawaited(HapticFeedback.selectionClick());
    }
    context.read<ReaderHighlightFocusCubit>().clear();
    context.read<ReaderImageSelectionCubit>().deselect();
    context.read<ReaderUiCubit>().hideChrome();
    final bloc = context.read<ReaderBloc>();
    final details = TextSelectionDetails.of(
      selection.section.prepared,
      selection.range,
      sectionCfi: selection.section.sectionCfi,
      text: selection.text,
      highlights: [
        for (final highlight in bloc.state.highlights)
          if (!highlight.isImageArea && highlight.cfiRange != null)
            SavedTextHighlight(
              id: highlight.id,
              cfi: highlight.cfiRange!,
              text: highlight.text,
            ),
      ],
    );
    _selectionDetails = details;
    _selectionPosition = _fractionsOfView(selection.bounds);
    final payload = readerSelectionFromDetails(
      details,
      position: _selectionPosition,
    );
    selectionCubit.select(
      text: payload.text,
      normalizedText: payload.normalizedText,
      selectionKind: payload.selectionKind,
      contextText: payload.contextText,
      markedContextText: payload.markedContextText,
      normalizedMarkedContextText: payload.normalizedMarkedContextText,
      cfiRange: payload.cfiRange,
      normalizedCfiRange: payload.normalizedCfiRange,
      position: payload.position,
      progress: bloc.state.document?.readingProgress,
      chapterTitle: _chapterTitleOf(selection.section.index),
      highlightMerge: highlightMergeTargetFor(payload.highlightMerge),
    );
  }

  /// A tap on a page edge while text is selected turns the page, and the
  /// selection follows; anywhere else it clears the selection.
  bool _turnWithSelection(
    Offset point, {
    required ReaderSurface surface,
    required ReaderTapAxis axis,
  }) {
    final command = readerTapCommandFor(
      x: point.dx,
      y: point.dy,
      chromeVisible: false,
      axis: axis,
    );
    switch (command) {
      case ReaderTapCommand.physicalLeftPage:
        surface.pageLeft();
      case ReaderTapCommand.physicalRightPage:
        surface.pageRight();
      case ReaderTapCommand.previousPage:
        surface.prevPage();
      case ReaderTapCommand.nextPage:
        surface.nextPage();
      case ReaderTapCommand.toggleChrome:
        return false;
    }
    return true;
  }

  ReaderSelection? _currentSelection() {
    final details = _selectionDetails;
    return details == null
        ? null
        : readerSelectionFromDetails(details, position: _selectionPosition);
  }

  ReaderSelectionPosition? _fractionsOfView(Rect? rect) {
    final box = context.findRenderObject();
    if (rect == null || box is! RenderBox || !box.hasSize) return null;
    final size = box.size;
    if (size.isEmpty) return null;
    return ReaderSelectionPosition(
      left: rect.left / size.width,
      top: rect.top / size.height,
      right: rect.right / size.width,
      bottom: rect.bottom / size.height,
    );
  }

  /// The selection popup asks for the preview while it builds.
  void _setPreview(String? cfi, Color? color) {
    if (!mounted) return;
    _preview = cfi == null || color == null ? null : (cfi: cfi, color: color);
    _rebuild();
  }

  void _setSearchMark(String? cfi) {
    if (!mounted) return;
    _searchMarkCfi = cfi;
    _rebuild();
  }

  // Highlights.

  /// What section [section] shows tinted: saved highlights (oldest first,
  /// so the newest is on top and answers taps), the preview of the
  /// selection's colour, then the search hit on top.
  List<TextHighlight> _highlightsOf(int section, List<Highlight> highlights) {
    final layout = _controller?.layout.laidOut(section);
    if (layout == null) return const [];
    if (!identical(highlights, _lastHighlightsRef) ||
        _lastHighlightsTheme != widget.readerTheme) {
      _lastHighlightsRef = highlights;
      _lastHighlightsTheme = widget.readerTheme;
      _placedHighlights.clear();
    }
    var cached = _placedHighlights[section];
    if (cached == null || !identical(cached.layout, layout)) {
      final opacity = readerHighlightOpacity(widget.readerTheme);
      final ordered = [...highlights]
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final items = <TextHighlight>[];
      for (final highlight in ordered) {
        final cfi = highlight.cfiRange;
        if (highlight.isImageArea || cfi == null) continue;
        final range = _rangeIn(layout, cfi);
        if (range == null) continue;
        items.add(
          TextHighlight(
            id: highlight.id,
            range: range,
            color: readerHighlightColor(
              highlight.color,
              widget.readerTheme,
            ).withValues(alpha: opacity),
          ),
        );
      }
      cached = (layout: layout, items: items);
      _placedHighlights[section] = cached;
    }
    final preview = _preview;
    final previewRange = preview == null ? null : _rangeIn(layout, preview.cfi);
    final search = _searchMarkCfi;
    final searchRange = search == null ? null : _rangeIn(layout, search);
    if (previewRange == null && searchRange == null) return cached.items;
    return [
      ...cached.items,
      if (previewRange != null)
        TextHighlight(
          id: _previewHighlightId,
          range: previewRange,
          color: preview!.color,
        ),
      if (searchRange != null)
        TextHighlight(
          id: _searchActiveHighlightId,
          range: searchRange,
          color: _searchMarkColor,
        ),
    ];
  }

  TextPointRange? _rangeIn(TextSectionLayout layout, String cfi) {
    if (_source?.sectionOfCfi(cfi) != layout.index) return null;
    final parsed = Cfi.tryParse(cfi);
    if (parsed == null) return null;
    final doc = layout.prepared.document;
    try {
      return doc.textRangeOf(cfiToRange(doc, parsed));
    } on CfiResolveException {
      return null;
    }
  }

  void _onHighlightTap(TextHighlight highlight, Rect rect) {
    if (_tintIds.contains(highlight.id)) return;
    context.read<ReaderUiCubit>().hideChrome();
    context.read<ReaderSelectionCubit>().deselect();
    context.read<ReaderImageSelectionCubit>().deselect();
    widget.surface.clearSelection();
    final spread = _controller?.spreadAt(0);
    final contextText = spread == null
        ? ''
        : buildSelectionContext(
            spread.layout.prepared.document,
            highlight.range,
          ).contextText;
    context.read<ReaderHighlightFocusCubit>().focus(
      ReaderHighlightTap(
        highlightId: highlight.id,
        position: _fractionsOfView(rect),
        contextText: contextText,
      ),
    );
  }

  // Links and notes.

  Future<void> _onLinkTap(TextSectionLayout section, int link) async {
    final source = _source;
    final controller = _controller;
    if (source == null || controller == null) return;
    final target = await resolveTextLink(source, section.prepared, link);
    if (!mounted || target == null) return;
    switch (target) {
      case ExternalTextLink(:final href):
        widget.onExternalLink?.call(href);
      case InternalTextLink(:final target, :final reference):
        if (reference != FootnoteReference.no) {
          final note = await controller.layout.prepareFootnote(
            target,
            extract: reference == FootnoteReference.maybe,
          );
          if (!mounted) return;
          if (note != null) {
            await _showFootnote(note);
            return;
          }
        }
        await controller.goToTarget(target);
    }
  }

  Future<void> _showFootnote(PreparedFootnote note) async {
    final images = _images;
    final controller = _controller;
    if (images == null || controller == null) return;
    await images.probe(note.content.imageKeys.values);
    if (!mounted) return;
    final style = controller.layout.style;
    final styler = InlineStyler(
      bookStyle: style,
      fonts: _bookFonts().withBookFamilies(
        controller.layout.bookFamilies,
        bookInk: controller.layout.bookInk,
      ),
    );
    final theme = widget.readerTheme;
    await showAppBottomSheet<void>(
      context,
      builder: (sheetContext) => ColoredBox(
        color: theme.backgroundColor,
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.6,
            ),
            child: TextFragmentView(
              boxes: note.content.boxes,
              bookStyle: style,
              styler: styler,
              images: images,
              imageKey: (src) => note.content.imageKeys[src],
              document: note.content.document,
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              maxImageHeight: MediaQuery.sizeOf(sheetContext).height * 0.4,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final highlights = context.select<ReaderBloc, List<Highlight>>(
      (b) => b.state.highlights,
    );
    final bookmarks = context.select<ReaderBloc, List<SourceBookmark>>(
      (b) => b.state.bookmarks,
    );
    final theme = widget.readerTheme;
    if (controller == null || _book == null) {
      return ColoredBox(color: theme.backgroundColor);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onBookmarksChanged(bookmarks);
    });
    final surface = widget.surface;
    final pageTurnStyle = widget.appearance.pageTurnStyle;
    final pages = TextPagesView(
      controller: controller,
      axis: _nativePageAxis(pageTurnStyle),
      backgroundColor: theme.backgroundColor,
      highlightsOf: (section) => _highlightsOf(section, highlights),
      onTap: (point) => _dispatchReaderTap(
        context,
        x: point.dx,
        y: point.dy,
        surface: surface,
        isComic: false,
        axis: _readerTapAxisForPageTurnStyle(pageTurnStyle),
      ),
      onLinkTap: (section, link) => unawaited(_onLinkTap(section, link)),
      onHighlightTap: _onHighlightTap,
      onSelectionChanged: _onSelectionChanged,
      onSelectionTap: (point) => _turnWithSelection(
        point,
        surface: surface,
        axis: _readerTapAxisForPageTurnStyle(pageTurnStyle),
      ),
      onSelectionAdjusting: context.read<ReaderSelectionCubit>().setAdjusting,
      // The reader shows its own context panel for a selection.
      contextMenuBuilder: (context, state) => const SizedBox.shrink(),
      trackedHighlight: _searchActiveHighlightId,
      onHighlightRects: (rects) => _activeHitRects.value = rects,
    );
    return Stack(
      children: [
        Positioned.fill(child: pages),
        Positioned.fill(
          child: ReaderSearchOcclusionMarker(
            rects: _activeHitRects,
            bottomInset: widget.searchOverlayBottomFraction,
          ),
        ),
      ],
    );
  }
}

/// The reader's style for text vellum lays out, on top of the book's own
/// CSS.
BookStyle _vellumBookStyle(
  BuildContext context, {
  required ReaderAppearancePreferences appearance,
  required ReaderThemeData theme,
}) {
  final layout = BookLayoutPreset.fromId(appearance.layoutId).data;
  final font = ReaderFontPreset.fromId(appearance.fontId);
  final fontScale = layout.fontSize * _vellumDeviceFontScale(context);
  return BookStyle(
    fontScale: fontScale,
    fontFamily: font.fontFamily,
    fontWeight: layout.fontWeight.round(),
    letterSpacing: layout.letterSpacing,
    lineHeight: appearance.lineHeight,
    paragraphSpacing: layout.paragraphSpacing,
    textIndent: layout.textIndent,
    textColor: theme.primaryTextColor.toARGB32(),
    backgroundColor: theme.backgroundColor.toARGB32(),
    justify: appearance.textAlignment == ReaderTextAlignment.justify,
    overrideFont: appearance.overrideFont,
    overrideColor: appearance.overrideColor,
    useBookLayout: appearance.useBookLayout,
    // Pages hold as many lines as the WebView reader's did: on iOS it was
    // WebKit, whose line heights are whole pixels and, under foliate-js's
    // `-webkit-line-box-contain`, never shorter than the glyphs.
    wholePixelLineHeights: _webKitLines,
    glyphLineBoxes: _webKitLines,
    // The WebView reader's limits: WebKit-only properties, so Android
    // hyphenated with Chromium's defaults.
    hyphenate: layout.hyphenate,
    hyphenateLimitBefore: _webKitLines ? 3 : 2,
    hyphenateLimitLines: _webKitLines ? 2 : null,
    // Text size, headings, quotes, code and link colours.
    readerStyleSheet: buildBookCustomCSS(
      theme: theme,
      sizes: BookCustomCssSizes(
        rootFontSize: 16 * fontScale,
        textScale: appearance.textScale,
        lineHeight: appearance.lineHeight,
      ),
    ),
    media: _vellumMedia(context),
  );
}

/// The window the book's media queries and viewport units see: the
/// reader's, on this screen, in the system's colour scheme.
CssMediaEnvironment _vellumMedia(BuildContext context) {
  final window = MediaQuery.sizeOf(context);
  final display = View.maybeOf(context)?.display;
  final screen = display == null || display.size.isEmpty
      ? window
      : display.size / display.devicePixelRatio;
  return CssMediaEnvironment(
    viewportWidth: window.width,
    viewportHeight: window.height,
    deviceWidth: screen.width,
    deviceHeight: screen.height,
    devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    darkColorScheme:
        MediaQuery.platformBrightnessOf(context) == Brightness.dark,
    reducedMotion: MediaQuery.disableAnimationsOf(context),
  );
}

/// Whether the WebView reader on this platform was WebKit's, whose lines
/// the pages keep.
bool get _webKitLines =>
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.macOS;

double _vellumDeviceFontScale(BuildContext context) => readerDeviceFontScale(
  platform: defaultTargetPlatform,
  viewportSize: MediaQuery.sizeOf(context),
);

/// CSS generics resolve to the app's bundled faces; symbols come from the
/// symbol font; [ink] is the reader's fonts' ink, for WebKit's line
/// boxes.
BookFonts _vellumBookFonts(Map<String, FontInk> ink) => BookFonts(
  serif: AppTypography.fontFamilySerif,
  sansSerif: AppTypography.fontFamilyOpenSans,
  monospace: defaultTargetPlatform == TargetPlatform.iOS
      ? 'Menlo'
      : 'monospace',
  fallback: const [AppTypography.fontFamilySymbols],
  ink: ink,
);

const _previewHighlightId = 'readflex-selection-preview';
const _searchHighlightId = 'readflex-search-mark';
const _searchActiveHighlightId = 'readflex-search-active';

/// Tints that are not saved highlights: taps on them fall through.
const _tintIds = {
  _previewHighlightId,
  _searchHighlightId,
  _searchActiveHighlightId,
};

/// The active search hit's tint.
const _searchMarkColor = Color(0x66FFB300);

/// Opens a reflowable book file with vellum by its format.
Future<Object> _openTextBook(ReaderDocument document) async {
  final path = document.filePath;
  return switch (document.format) {
    BookFormat.fb2 => Fb2Book.open(path),
    BookFormat.mobi || BookFormat.azw3 => MobiBook.open(path),
    _ => EpubBook.open(path),
  };
}
