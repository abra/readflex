part of 'reader_screen.dart';

/// Hosts a saved article on the text engine (`package:vellum`) as one
/// scrolling column and translates its events into the reader bloc and
/// cubit updates every page body produces: the position
/// (the sentence at the middle of the view, its heading, minutes left),
/// contents, sentence bookmarks, selections with their anchors and
/// context, saved highlights, search tints and links.
class _ReaderArticleBody extends StatefulWidget {
  const _ReaderArticleBody({
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
  final ReaderArticleSurface surface;

  /// The share of the view the search bar covers, where the active hit
  /// is marked when it hides there.
  final double searchOverlayBottomFraction;
  final ValueChanged<BookPosition>? onPositionChanged;
  final VoidCallback? onReady;
  final VoidCallback? onLoading;
  final ValueChanged<String>? onExternalLink;

  @override
  State<_ReaderArticleBody> createState() => _ReaderArticleBodyState();
}

class _ReaderArticleBodyState extends State<_ReaderArticleBody> {
  ArticleTextSource? _source;
  TextScrollController? _controller;
  BookImageCache? _images;
  ReaderArticleSession? _session;
  int _openGeneration = 0;
  bool _ready = false;

  /// The section laid out when the body last built, and the index of
  /// its document.
  TextSectionLayout? _shownSection;
  ArticleIndex? _index;

  /// The layout whose contents, with where each entry starts, went to
  /// the bloc.
  TextSectionLayout? _tocLayout;

  /// What was last reported as the position, and how long ago.
  _ArticlePositionReport? _reported;
  final _sinceReport = Stopwatch();
  Timer? _pendingReport;

  /// The anchor of the sentence last read and its stored form, memoized
  /// by sentence: positions are reported while scrolling.
  ({ContentDocument doc, int sentence, _SentenceAnchor? anchor})? _anchorMemo;

  /// What text actions get for the selection on screen.
  ArticleSelection? _selection;
  ReaderSelectionPosition? _selectionPosition;

  /// The highlight tint the reader previews on the selection.
  ({String cfi, Color color})? _preview;
  List<ArticleSearchHit>? _searchHits;
  String? _searchMarkCfi;

  /// Where the active search hit is drawn in the view.
  final _activeHitRects = ValueNotifier<List<Rect>>(const []);

  /// Saved highlights placed in the document, for the list, theme and
  /// document they were placed for.
  ({
    List<Highlight> source,
    ReaderThemeData theme,
    ContentDocument doc,
    List<TextHighlight> items,
  })?
  _placedHighlights;

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
  void didUpdateWidget(covariant _ReaderArticleBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document.id != widget.document.id ||
        oldWidget.document.filePath != widget.document.filePath) {
      _ready = false;
      _notifyLoading();
      _closeArticle();
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
    _closeArticle();
    _activeHitRects.dispose();
    super.dispose();
  }

  // Opening.

  Future<void> _open() async {
    final generation = ++_openGeneration;
    final document = widget.document;
    final ArticleTextSource source;
    try {
      source = await ArticleTextSource.open(
        document.filePath,
        language: document.language,
      );
    } catch (error, stackTrace) {
      if (!mounted || generation != _openGeneration) return;
      _debugTraceReader('_ReaderArticleBody open failed: $error');
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
    final opening = _openingOf(document);
    final controller = TextScrollController(
      source: source,
      style: _bookStyle(),
      fonts: _vellumBookFonts(_fontInk),
      images: images,
      settings: _pageSettings(),
      initialPoint: opening.anchor == null
          ? null
          : (doc) => switch (opening.anchor!.elementIn(doc)) {
              null => null,
              final element => TextPoint(element, 0),
            },
      initialFraction: opening.fraction,
    );
    final session = ReaderArticleSession(
      controller: controller,
      index: _currentIndex,
      onToggleBookmark: _toggleBookmark,
      onSearchHits: _setSearchHits,
      onSearchMark: _setSearchMark,
      onSelectionPreview: _setPreview,
      currentSelection: _currentSelection,
    );
    controller.addListener(_onControllerChanged);
    widget.surface.attach(session);
    setState(() {
      _source = source;
      _images = images;
      _controller = controller;
      _session = session;
    });
    final bloc = context.read<ReaderBloc>();
    bloc.add(ReaderTocUpdated(items: _tocItems(source, null)));
    bloc.add(
      ReaderDocumentFeaturesUpdated(
        features: ReaderDocumentFeatures(
          format: 'html',
          hasTableOfContents: source.toc.isNotEmpty,
          hasSearchableText: true,
        ),
      ),
    );
  }

  /// Where the article opens, as the shell restored it: at its start or
  /// end when it was left there, else at the saved sentence, else at the
  /// saved share of the text.
  static ({ArticleAnchor? anchor, double? fraction}) _openingOf(
    ReaderDocument document,
  ) {
    final progress = document.readingProgress;
    if (progress <= _articleStartThreshold) return (anchor: null, fraction: 0);
    if (progress >= _articleEndThreshold) return (anchor: null, fraction: 1);
    return (
      anchor: ArticleAnchor.decode(document.currentCfi),
      fraction: progress,
    );
  }

  void _closeArticle() {
    _openGeneration++;
    _pendingReport?.cancel();
    _pendingReport = null;
    final session = _session;
    if (session != null) widget.surface.detach(session);
    _controller?.removeListener(_onControllerChanged);
    _controller?.dispose();
    _images?.dispose();
    final source = _source;
    if (source != null) unawaited(source.close());
    _source = null;
    _images = null;
    _controller = null;
    _session = null;
    _shownSection = null;
    _index = null;
    _tocLayout = null;
    _reported = null;
    _anchorMemo = null;
    _selection = null;
    _placedHighlights = null;
  }

  // Appearance.

  void _applyAppearance() {
    final controller = _controller;
    if (controller == null) return;
    controller
      ..style = _bookStyle()
      ..fonts = _vellumBookFonts(_fontInk)
      ..settings = _pageSettings();
  }

  /// The reader's style as books get it; an article has no publisher CSS,
  /// so the reader's layout, font and colours always apply, as in the
  /// article shell, whose softer captions, quotes and table rules come
  /// before the reader's sheet (its dark theme sets its own).
  BookStyle _bookStyle() {
    final style = _vellumBookStyle(
      context,
      appearance: widget.appearance,
      theme: widget.readerTheme,
    );
    return style.copyWith(
      useBookLayout: true,
      overrideFont: true,
      overrideColor: true,
      readerStyleSheet:
          '${_articleColors(widget.readerTheme.primaryTextColor)}\n'
          '${style.readerStyleSheet}',
    );
  }

  /// The shell's `color-mix` of the text colour with transparency.
  static String _articleColors(Color text) {
    String mix(double alpha) =>
        'rgba(${(text.r * 255).round()}, ${(text.g * 255).round()}, '
        '${(text.b * 255).round()}, $alpha)';
    return 'figcaption { color: ${mix(0.72)} !important; }\n'
        'blockquote { color: ${mix(0.86)} !important; }\n'
        'th, td { border-color: ${mix(0.22)} !important; }';
  }

  /// The reader's fonts' ink, for WebKit's line boxes.
  Map<String, FontInk> _fontInk = const {};

  /// The shell's `<main>`: the side margin as `articleSidePadding` made
  /// it, below the status bar and above the home indicator, at most the
  /// reader's measure wide.
  TextPageSettings _pageSettings() {
    final appearance = widget.appearance;
    final layout = BookLayoutPreset.fromId(appearance.layoutId).data;
    final padding = MediaQuery.paddingOf(context);
    final columns = readerTextColumns(
      wideWindow: AppWindowSize.isWide(context),
      fixedLayout: false,
      columns: null,
    );
    final em = columns.maxLineWidthEm;
    final fontSize = layout.fontSize * _vellumDeviceFontScale(context);
    final side = appearance.sideMargin;
    return TextPageSettings(
      sideMarginPercent: side >= 0 && side < 100
          ? side / (100 - side) / 2 * 100
          : 3.2,
      topMargin: _kArticleReaderTopMargin + padding.top,
      bottomMargin: _kArticleReaderBottomMargin + padding.bottom,
      measure: em == null
          ? null
          : (em * 16 * fontSize * appearance.textScale).roundToDouble(),
      safeInlineInset: math.max(padding.left, padding.right),
    );
  }

  // The document.

  /// The index of the document laid out now, made once per document.
  ArticleIndex? _currentIndex() {
    final section = _controller?.section;
    if (section == null) return null;
    final doc = section.prepared.document;
    final index = _index;
    if (index != null && identical(index.document, doc)) return index;
    return _index = ArticleIndex.of(doc);
  }

  /// The contents, the article's headings by depth (level 1 at the top,
  /// as the drawer indents them), each with the share of the scroll where
  /// it starts once [section] is all laid out.
  List<ReaderTocItem> _tocItems(
    ArticleTextSource source,
    TextSectionLayout? section,
  ) {
    final controller = _controller;
    final doc = section?.prepared.document;
    final max = controller?.maxScroll ?? 0;
    double? startOf(String href) {
      if (doc == null || controller == null || !href.startsWith('#')) {
        return null;
      }
      final element = doc.elementIndexById(href.substring(1));
      if (element == ContentDocument.none) return null;
      final offset = controller.contentOffsetOf(TextPoint(element, 0));
      if (offset == null) return null;
      return max <= 0 ? 0 : (offset / max).clamp(0.0, 1.0);
    }

    final items = <ReaderTocItem>[];
    void add(List<BookNavItem> entries, int level) {
      for (final entry in entries) {
        final href = entry.href ?? '';
        items.add(
          ReaderTocItem(
            label: entry.label,
            href: href,
            id: href.startsWith('#') ? href.substring(1) : null,
            level: level,
            startPercentage: startOf(href),
          ),
        );
        final children = entry.subitems;
        if (children != null) add(children, level + 1);
      }
    }

    add(source.toc, 1);
    return items;
  }

  // Position and bookmarks.

  void _onControllerChanged() {
    if (!mounted) return;
    final controller = _controller;
    if (controller == null) return;
    final error = controller.error;
    if (controller.position == null && error != null) {
      context.read<ReaderBloc>().add(
        ReaderSurfaceFailed(sourceId: widget.document.id, error: error),
      );
      return;
    }
    final section = controller.section;
    if (section != null && section.isComplete && _tocLayout != section) {
      _tocLayout = section;
      final source = _source;
      if (source != null) {
        context.read<ReaderBloc>().add(
          ReaderTocUpdated(items: _tocItems(source, section)),
        );
      }
    }
    if (controller.position != null) {
      _reportPosition();
      if (!_ready) {
        _ready = true;
        widget.onReady?.call();
      }
    }
    // Highlights are placed per document: a new layout draws them anew.
    if (!identical(section, _shownSection)) {
      _shownSection = section;
      _rebuild();
    }
  }

  /// A rebuild, after the frame when the change comes during one (a
  /// selection cleared while the screen is torn down).
  void _rebuild() {
    if (!mounted) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  /// The position as the shell reported it: at most one report every
  /// [_articleReportInterval] while scrolling, the place it settles on
  /// after, and a change of end at once.
  void _reportPosition({bool force = false}) {
    final next = _positionNow();
    if (next == null) return;
    final last = _reported;
    if (!force && last != null && !next.differsFrom(last)) return;
    final wait = _articleReportInterval - _sinceReport.elapsed;
    if (!force &&
        last != null &&
        next.position.atEnd == last.position.atEnd &&
        wait > Duration.zero) {
      _pendingReport ??= Timer(wait, () {
        _pendingReport = null;
        if (mounted) _reportPosition();
      });
      return;
    }
    _pendingReport?.cancel();
    _pendingReport = null;
    _reported = next;
    _sinceReport
      ..reset()
      ..start();
    final position = next.position;
    _debugTraceReader(
      '_ReaderArticleBody position '
      'progress=${position.fraction.toStringAsFixed(3)} '
      'chapter=${position.chapterTitle} '
      'reason=${position.relocationReason}',
    );
    context.read<ReaderBloc>().add(
      ReaderBookPositionUpdated.fromBookPosition(position),
    );
    widget.onPositionChanged?.call(position);
  }

  _ArticlePositionReport? _positionNow() {
    final position = _controller?.position;
    final index = _currentIndex();
    final point = position?.point;
    if (position == null || index == null || point == null) return null;
    final sentence = index.sentenceAt(point);
    final anchor = sentence == null ? null : _anchorOf(index, sentence);
    final bookmark = _bookmarkFor(
      anchor,
      context.read<ReaderBloc>().state.bookmarks,
    );
    return _ArticlePositionReport(
      sentence: sentence,
      position: BookPosition(
        cfi: anchor?.cfi ?? '',
        fraction: position.fraction,
        chapterTitle: index.headingBefore(point.node),
        relocationReason: switch (position.reason) {
          TextScrollReason.scroll => 'scroll',
          TextScrollReason.navigation => 'anchor',
          TextScrollReason.layout => 'style',
        },
        pageProgressionRtl: false,
        atStart: position.atStart,
        atEnd: position.atEnd,
        minutesLeft: index.minutesLeft(
          sentence,
          position.fraction,
          atEnd: position.atEnd,
        ),
        bookmarkExists: bookmark != null,
        bookmarkCfi: bookmark?.cfi,
        bookmarkId: bookmark?.id,
      ),
    );
  }

  _SentenceAnchor? _anchorOf(ArticleIndex index, int sentence) {
    final memo = _anchorMemo;
    if (memo != null &&
        identical(memo.doc, index.document) &&
        memo.sentence == sentence) {
      return memo.anchor;
    }
    final anchor = switch (ArticleAnchor.forSentence(
      index.document,
      sentence,
    )) {
      null => null,
      final found => (anchor: found, cfi: found.encode()),
    };
    _anchorMemo = (doc: index.document, sentence: sentence, anchor: anchor);
    return anchor;
  }

  /// The bookmark of the sentence [anchor] names: by its anchor, or by
  /// its text (`bookmarkForAnchor`).
  static SourceBookmark? _bookmarkFor(
    _SentenceAnchor? anchor,
    List<SourceBookmark> bookmarks,
  ) {
    if (anchor == null || bookmarks.isEmpty) return null;
    final cfi = anchor.cfi;
    final exact = anchor.anchor.sentenceText;
    SourceBookmark? byText;
    for (final bookmark in bookmarks) {
      if (bookmark.cfi.isEmpty) continue;
      if (bookmark.cfi == cfi) return bookmark;
      final text = normalizeArticleText(
        bookmark.anchorExact?.isNotEmpty ?? false
            ? bookmark.anchorExact
            : bookmark.content,
      );
      if (exact.isNotEmpty && text == exact) byText ??= bookmark;
    }
    return byText;
  }

  void _onBookmarksChanged(List<SourceBookmark> bookmarks) {
    final reported = _reported;
    if (reported == null) return;
    final next = _positionNow();
    if (next != null &&
        next.position.bookmarkExists != reported.position.bookmarkExists) {
      _reportPosition(force: true);
    }
  }

  /// Bookmarks the sentence read, or removes its bookmark
  /// (`toggleBookmarkHere`).
  void _toggleBookmark() {
    final controller = _controller;
    final index = _currentIndex();
    final point = controller?.position?.point;
    if (controller == null || index == null || point == null) return;
    final sentence = index.sentenceAt(point);
    final found = sentence == null ? null : _anchorOf(index, sentence);
    if (found == null) return;
    final anchor = found.anchor;
    final bloc = context.read<ReaderBloc>();
    final existing = _bookmarkFor(found, bloc.state.bookmarks);
    final content = anchor.sentenceText.isNotEmpty
        ? anchor.sentenceText
        : existing?.content ?? '';
    bloc.add(
      ReaderBookmarkChanged(
        remove: existing != null,
        id: existing?.id,
        cfi: found.cfi,
        content: content,
        progress: controller.position!.fraction,
        anchorExact: anchor.sentenceText.isNotEmpty
            ? anchor.sentenceText
            : existing?.anchorExact,
        anchorPrefix: anchor.prefix.isNotEmpty
            ? anchor.prefix
            : existing?.anchorPrefix,
        anchorSuffix: anchor.suffix.isNotEmpty
            ? anchor.suffix
            : existing?.anchorSuffix,
      ),
    );
  }

  // Selection.

  void _onSelectionChanged(TextPagesSelection? selection) {
    final selectionCubit = context.read<ReaderSelectionCubit>();
    final index = _currentIndex();
    final details = selection == null || index == null
        ? null
        : ArticleSelection.of(
            index.document,
            selection.range,
            highlights: _savedHighlights(
              context.read<ReaderBloc>().state.highlights,
            ),
          );
    _selection = details;
    if (selection == null || details == null) {
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
    _selectionPosition = _fractionsOfView(selection.bounds);
    final payload = _currentSelection()!;
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
      scrollOffset: payload.scrollOffset,
      progress: bloc.state.document?.readingProgress,
      chapterTitle: bloc.state.chapterTitle,
      highlightMerge: highlightMergeTargetFor(payload.highlightMerge),
    );
  }

  /// The selection as the shell's `textSelectionPayload` gave it: exact,
  /// its anchor as its own normalized one.
  ReaderSelection? _currentSelection() {
    final details = _selection;
    if (details == null) return null;
    final cfi = details.cfi.isEmpty ? null : details.cfi;
    return ReaderSelection(
      text: details.text,
      normalizedText: details.text,
      selectionKind: SelectionKind.exact.wireName,
      contextText: details.contextText,
      markedContextText: details.markedContextText,
      normalizedMarkedContextText: details.markedContextText,
      cfiRange: cfi,
      normalizedCfiRange: cfi,
      position: _selectionPosition,
      scrollOffset: _controller?.scroll.hasClients ?? false
          ? _controller!.scroll.offset
          : null,
      highlightMerge: switch (details.highlightMerge) {
        null => null,
        final merge => ReaderHighlightMerge(
          cfiRange: merge.cfi,
          text: merge.text,
          highlightIds: merge.highlightIds,
        ),
      },
    );
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

  void _setSearchHits(List<ArticleSearchHit>? hits) {
    if (!mounted) return;
    _searchHits = hits;
    _rebuild();
  }

  void _setSearchMark(String? cfi) {
    if (!mounted) return;
    _searchMarkCfi = cfi;
    _rebuild();
  }

  // Highlights.

  static List<SavedTextHighlight> _savedHighlights(List<Highlight> source) => [
    for (final highlight in source)
      if (!highlight.isImageArea &&
          (highlight.cfiRange?.startsWith(ArticleAnchor.scheme) ?? false))
        SavedTextHighlight(
          id: highlight.id,
          cfi: highlight.cfiRange!,
          text: highlight.text,
        ),
  ];

  /// What the article shows tinted: saved highlights (oldest first, so
  /// the newest is on top and answers taps), every search hit, the
  /// active one, then the preview of the selection's colour on top.
  List<TextHighlight> _highlightsFor(List<Highlight> highlights) {
    final doc = _controller?.section?.prepared.document;
    if (doc == null) return const [];
    final theme = widget.readerTheme;
    var placed = _placedHighlights;
    if (placed == null ||
        !identical(placed.source, highlights) ||
        placed.theme != theme ||
        !identical(placed.doc, doc)) {
      final opacity = readerHighlightOpacity(theme);
      final ordered = [...highlights]
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final items = <TextHighlight>[];
      for (final highlight in ordered) {
        final cfi = highlight.cfiRange;
        if (highlight.isImageArea || cfi == null) continue;
        final range = ArticleAnchor.decode(cfi)?.rangeIn(doc);
        if (range == null) continue;
        items.add(
          TextHighlight(
            id: highlight.id,
            range: range,
            color: readerHighlightColor(
              highlight.color,
              theme,
            ).withValues(alpha: opacity),
          ),
        );
      }
      placed = (source: highlights, theme: theme, doc: doc, items: items);
      _placedHighlights = placed;
    }
    final hits = _searchHits;
    final active = _searchMarkCfi;
    final activeRange = active == null
        ? null
        : ArticleAnchor.decode(active)?.rangeIn(doc);
    final preview = _preview;
    final previewRange = preview == null
        ? null
        : ArticleAnchor.decode(preview.cfi)?.rangeIn(doc);
    if ((hits == null || hits.isEmpty) &&
        activeRange == null &&
        previewRange == null) {
      return placed.items;
    }
    return [
      ...placed.items,
      if (hits != null)
        for (final hit in hits)
          if (hit.range case final range? when hit.cfi != active)
            TextHighlight(
              id: _searchHighlightId,
              range: range,
              color: _searchMatchColor,
            ),
      if (activeRange != null)
        TextHighlight(
          id: _searchActiveHighlightId,
          range: activeRange,
          color: _searchMarkColor,
        ),
      if (previewRange != null)
        TextHighlight(
          id: _previewHighlightId,
          range: previewRange,
          color: preview!.color,
        ),
    ];
  }

  void _onHighlightTap(TextHighlight highlight, Rect rect) {
    if (_tintIds.contains(highlight.id)) return;
    context.read<ReaderUiCubit>().hideChrome();
    context.read<ReaderSelectionCubit>().deselect();
    context.read<ReaderImageSelectionCubit>().deselect();
    widget.surface.clearSelection();
    final doc = _controller?.section?.prepared.document;
    context.read<ReaderHighlightFocusCubit>().focus(
      ReaderHighlightTap(
        highlightId: highlight.id,
        position: _fractionsOfView(rect),
        contextText: doc == null
            ? ''
            : normalizeArticleText(doc.textOfRange(highlight.range)),
      ),
    );
  }

  // Links.

  /// The shell's `classifyArticleLink`: a fragment scrolls in place, a
  /// web, mail or phone address leaves for the reader's prompt, anything
  /// else (a path inside the saved article) does nothing.
  void _onLinkTap(TextSectionLayout section, int link) {
    final href = section.prepared.document.attributeOf(link, 'href')?.trim();
    if (href == null || href.isEmpty) return;
    if (href.startsWith('#')) {
      if (href.length > 1) widget.surface.goToHref(href);
      return;
    }
    final uri = Uri.tryParse(href);
    if (uri == null || !uri.hasScheme) return;
    if (const {'http', 'https', 'mailto', 'tel'}.contains(uri.scheme)) {
      widget.onExternalLink?.call(uri.toString());
    }
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
    if (controller == null) return ColoredBox(color: theme.backgroundColor);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onBookmarksChanged(bookmarks);
    });
    return Stack(
      children: [
        Positioned.fill(
          child: TextScrollView(
            controller: controller,
            backgroundColor: theme.backgroundColor,
            highlights: _highlightsFor(highlights),
            onTap: (_) {
              context.read<ReaderSelectionCubit>().deselect();
              context.read<ReaderUiCubit>().toggleChrome();
            },
            onLinkTap: _onLinkTap,
            onHighlightTap: _onHighlightTap,
            onSelectionChanged: _onSelectionChanged,
            // The reader shows its own context panel for a selection.
            contextMenuBuilder: (context, state) => const SizedBox.shrink(),
            trackedHighlight: _searchActiveHighlightId,
            onHighlightRects: (rects) => _activeHitRects.value = rects,
          ),
        ),
        Positioned.fill(
          child: _ArticleSystemBarBackground(color: theme.backgroundColor),
        ),
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

/// A sentence's anchor and the form it is stored in.
typedef _SentenceAnchor = ({ArticleAnchor anchor, String cfi});

/// A position report and the sentence it is at.
class _ArticlePositionReport {
  const _ArticlePositionReport({
    required this.sentence,
    required this.position,
  });

  final int? sentence;
  final BookPosition position;

  /// Whether reporting [other] after this one says something new: another
  /// sentence, progress moved by [_articleProgressStep], an edge reached
  /// or left, or the bookmark state changed.
  bool differsFrom(_ArticlePositionReport other) =>
      sentence != other.sentence ||
      (position.fraction - other.position.fraction).abs() >=
          _articleProgressStep ||
      position.atStart != other.position.atStart ||
      position.atEnd != other.position.atEnd ||
      position.bookmarkExists != other.position.bookmarkExists;
}

/// The shell's emit rules: a report every 140 ms at most while scrolling,
/// or when progress moves this far, and its thresholds for the edges.
const _articleReportInterval = Duration(milliseconds: 140);
const _articleProgressStep = 0.004;
const _articleStartThreshold = 0.001;
const _articleEndThreshold = 0.999;

/// The tint for every search hit but the active one.
const _searchMatchColor = Color(0x2900D4D8);
