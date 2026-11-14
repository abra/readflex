import 'dart:async';

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pagecraft/djvu.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'reader_bloc.dart';
import 'reader_diagnostics.dart';
import 'reader_djvu_surface.dart';
import 'reader_document_features.dart';
import 'reader_highlight_color.dart';
import 'reader_highlight_focus_cubit.dart';
import 'reader_image_selection_cubit.dart';
import 'reader_page_input.dart';
import 'reader_page_location.dart';
import 'reader_page_turn.dart';
import 'reader_position.dart';
import 'reader_selection.dart';
import 'reader_selection_cubit.dart';
import 'reader_text_selection_style.dart';
import 'reader_toc_item.dart';
import 'reader_ui_cubit.dart';

/// Hosts the DjVu engine (`package:pagecraft`) and translates its events into
/// the reader bloc and cubit updates every page body produces: pages,
/// position, bookmarks, outline, text selection, saved highlights, search
/// marks and image-area annotations on pages without hidden text.
class ReaderDjvuBody extends StatefulWidget {
  const ReaderDjvuBody({
    super.key,
    required this.document,
    required this.readerTheme,
    required this.surface,
    required this.pageTurnStyle,
    required this.pageAnimation,
    this.onPositionChanged,
    this.onReady,
    this.onLoading,
  });

  final ReaderDocument document;
  final ReaderThemeData readerTheme;
  final ReaderDjvuSurface surface;
  final ReaderPageTurnStyle pageTurnStyle;
  final ReaderPageAnimation pageAnimation;
  final ValueChanged<BookPosition>? onPositionChanged;
  final VoidCallback? onReady;
  final VoidCallback? onLoading;

  @override
  State<ReaderDjvuBody> createState() => _ReaderDjvuBodyState();
}

class _ReaderDjvuBodyState extends State<ReaderDjvuBody> {
  DjvuBook? _book;
  FixedPagesController? _controller;
  DjvuTextLayerCache? _layers;
  ReaderDjvuSession? _session;
  final _selection = DjvuTextSelection();
  final _draft = ComicImageAreaDraft();
  int _openGeneration = 0;
  bool _ready = false;
  int? _reportedBookmarkedPage;
  bool _searchableTextReported = false;

  /// Outline titles by the page they open, for the chrome's chapter line.
  Map<int, String> _outlineTitles = const {};

  ({int page, DjvuTextRange range})? _searchMark;

  List<Highlight>? _lastHighlightsRef;
  List<Highlight>? _lastAreaHighlights;
  List<ComicImageArea>? _cachedAreas;
  ReaderThemeData? _lastHighlightsTheme;
  final _resolvedHighlights =
      <int, ({DjvuTextLayer layer, List<DjvuTextHighlight> items})>{};

  @override
  void initState() {
    super.initState();
    _applyDraftStyle();
    _notifyLoading();
    unawaited(_open());
  }

  void _notifyLoading() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_ready) widget.onLoading?.call();
    });
  }

  @override
  void didUpdateWidget(covariant ReaderDjvuBody oldWidget) {
    super.didUpdateWidget(oldWidget);
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
    _selection.dispose();
    _draft.dispose();
    super.dispose();
  }

  void _applyDraftStyle() {
    _draft.setStyle(
      color: readerImageHighlightColor(HighlightColor.yellow),
      opacity: readerImageSelectionPreviewOpacity,
    );
  }

  Future<void> _open() async {
    final generation = ++_openGeneration;
    final document = widget.document;
    final DjvuBook book;
    try {
      book = await DjvuBook.open(document.filePath);
    } catch (error, stackTrace) {
      if (!mounted || generation != _openGeneration) return;
      debugTraceReader('ReaderDjvuBody open failed: $error');
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
      unawaited(book.close());
      return;
    }
    final bloc = context.read<ReaderBloc>();
    final controller = FixedPagesController(
      pageCount: book.pageCount,
      rtl: false,
      initialPage: initialReaderPage(document, book.pageCount),
    );
    final layers = DjvuTextLayerCache(book);
    final session = ReaderDjvuSession(
      controller: controller,
      book: book,
      layers: layers,
      selection: _selection,
      onToggleBookmark: _toggleBookmark,
      onSearchMark: _setSearchMark,
      draft: _draft,
    );
    controller.addListener(_onControllerChanged);
    layers.addListener(_onLayersChanged);
    widget.surface.attach(session);
    setState(() {
      _book = book;
      _controller = controller;
      _layers = layers;
      _session = session;
      _outlineTitles = _titlesByPage(book);
      _resolvedHighlights.clear();
      _searchMark = null;
      _searchableTextReported = false;
    });
    bloc.add(ReaderTocUpdated(items: _tocItems(book)));
    bloc.add(
      ReaderDocumentFeaturesUpdated(
        features: ReaderDocumentFeatures(
          format: 'djvu',
          hasTableOfContents: book.toc?.isNotEmpty ?? false,
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
    _resolvedHighlights.clear();
    _cachedAreas = null;
    _lastAreaHighlights = null;
    _selection.clear();
    _draft.clear();
  }

  // Outline.

  /// Entries flattened in order with their depth; an entry without a page
  /// keeps an empty href, which the surface ignores.
  static List<ReaderTocItem> _tocItems(DjvuBook book) {
    final items = <ReaderTocItem>[];
    void add(List<BookNavItem> entries, int level) {
      for (final entry in entries) {
        final href = entry.href ?? '';
        final page = book.resolveHref(href);
        items.add(
          ReaderTocItem(
            label: entry.label,
            href: page == null ? '' : href,
            level: level,
            startPercentage: page == null ? null : page / book.pageCount,
            startPage: page == null ? null : page + 1,
          ),
        );
        add(entry.subitems ?? const [], level + 1);
      }
    }

    add(book.toc ?? const [], 0);
    return items;
  }

  static Map<int, String> _titlesByPage(DjvuBook book) {
    final titles = <int, String>{};
    for (final entry in _tocItems(book)) {
      final page = book.resolveHref(entry.href);
      final title = readerChapterTitle(entry.label);
      if (page != null && title != null) titles.putIfAbsent(page, () => title);
    }
    return titles;
  }

  // Position and bookmarks.

  void _onControllerChanged() {
    if (!mounted) return;
    _reportPosition();
    _loadVisibleLayers();
  }

  BookPosition? _currentPosition() {
    final controller = _controller;
    if (controller == null) return null;
    final position = controller.position;
    final bookmark = readerBookmarkOnPage(
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
    debugTraceReader(
      'ReaderDjvuBody position '
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
    final bookmarked = readerBookmarkOnPage(bookmarks, controller.page) != null;
    final reported = _reportedBookmarkedPage == controller.page;
    if (bookmarked != reported) _reportPosition();
  }

  void _toggleBookmark() {
    final controller = _controller;
    if (controller == null) return;
    final bloc = context.read<ReaderBloc>();
    final page = controller.page;
    final existing = readerBookmarkOnPage(bloc.state.bookmarks, page);
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
    debugTraceReader('ReaderDjvuBody first page shown page=$page');
    setState(() => _ready = true);
    widget.onReady?.call();
  }

  // Text layers.

  /// Loads visible text only; bitmap prefetch does not enqueue native text work.
  void _loadVisibleLayers() {
    final controller = _controller;
    final layers = _layers;
    if (controller == null || layers == null) return;
    for (final page in controller.visiblePages) {
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
            format: 'djvu',
            hasTableOfContents: _book?.toc?.isNotEmpty,
            hasSearchableText: true,
            pageCount: _book?.pageCount,
          ),
        ),
      );
    }
    final loaded = layers?.loadedLayers.map((layer) => layer.pageIndex).toSet();
    if (loaded != null) {
      _resolvedHighlights.removeWhere((page, _) => !loaded.contains(page));
    }
    setState(() {});
  }

  // Selection, highlights, search.

  List<ComicImageArea> _areasFor(List<Highlight> highlights) {
    final cached = _cachedAreas;
    if (cached != null && identical(highlights, _lastAreaHighlights)) {
      return cached;
    }
    _lastAreaHighlights = highlights;
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
          color: readerImageHighlightColor(highlight.color),
        ),
    ];
  }

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
    // A scanned page without hidden text uses its page label in saved areas.
    imageSelectionCubit.select(
      pageIndex: page,
      rect: ReaderImageAreaRect(
        x: rect.left,
        y: rect.top,
        width: rect.width,
        height: rect.height,
      ),
      position: readerSelectionPositionForViewport(viewport),
      progress: bloc.state.document?.readingProgress,
      chapterTitle: null,
    );
  }

  void _onDraftCancelled() {
    final imageSelectionCubit = context.read<ReaderImageSelectionCubit>();
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
        position: readerSelectionPositionForViewport(viewport),
        contextText: '',
      ),
    );
  }

  void _onSelectionChanged(int page, DjvuTextRange range, Rect? viewport) {
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
    final selection = readerSelectionFromDjvuLayer(
      layer,
      range,
      position: readerSelectionPositionForViewport(viewport),
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

  void _onHighlightPressed(DjvuTextHighlight highlight, Rect? viewport) {
    context.read<ReaderUiCubit>().hideChrome();
    context.read<ReaderSelectionCubit>().deselect();
    context.read<ReaderImageSelectionCubit>().deselect();
    widget.surface.clearSelection();
    final layer = _layers?.peek(highlight.page);
    context.read<ReaderHighlightFocusCubit>().focus(
      ReaderHighlightTap(
        highlightId: highlight.id,
        position: readerSelectionPositionForViewport(viewport),
        contextText: layer?.contextOf(highlight.range).contextText ?? '',
      ),
    );
  }

  void _setSearchMark(int page, DjvuTextRange? range) {
    if (!mounted) return;
    setState(() {
      _searchMark = range == null ? null : (page: page, range: range);
    });
  }

  /// Saved text highlights of [page] placed on its text layer; resolved
  /// once per highlight list, layer and theme.
  List<DjvuTextHighlight> _highlightsFor(
    int page,
    DjvuTextLayer? layer,
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
    final items = <DjvuTextHighlight>[];
    for (final highlight in highlights) {
      final cfiRange = highlight.cfiRange;
      if (highlight.isImageArea || cfiRange == null) continue;
      if (fakeCfiToIndex(cfiRange) != page) continue;
      final range = resolveDjvuTextAnchor(
        layer,
        text: highlight.text,
        cfiRange: cfiRange,
      );
      if (range == null) continue;
      items.add(
        DjvuTextHighlight(
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
    return FixedPagesView(
      pages: DjvuPages(book),
      controller: controller,
      backgroundColor: widget.readerTheme.backgroundColor,
      axis: readerPageAxis(widget.pageTurnStyle),
      pageTurnAnimation: readerPageTurnAnimation(widget.pageAnimation),
      onTap: (point) => dispatchReaderTap(
        context,
        x: point.dx,
        y: point.dy,
        surface: surface,
        isComic: true,
        axis: readerTapAxisForPageTurnStyle(widget.pageTurnStyle),
      ),
      onPageShown: _onPageShown,
      pageSemanticsLabel: (page, count) =>
          context.l10n.readerPageNumber(page + 1),
      failedPageSemanticsLabel: (page) =>
          context.l10n.readerThumbnailUnavailable,
      pageOverlayBuilder: (context, page, imageRect) {
        final layer = layers.peek(page);
        if (layer == null) return const SizedBox.shrink();
        if (layer.isEmpty) {
          return ComicImageAreaLayer(
            page: page,
            imageRect: imageRect,
            controller: controller,
            draft: _draft,
            areas: _areasFor(highlights),
            onDraftCommitted: (rect, viewport) =>
                _onDraftCommitted(page, rect, viewport),
            onDraftCancelled: _onDraftCancelled,
            onDraftAdjustmentChanged: context
                .read<ReaderImageSelectionCubit>()
                .setAdjustment,
            onAreaPressed: _onAreaPressed,
          );
        }
        final info = book.pages[page];
        final mark = _searchMark;
        return DjvuTextOverlay(
          page: page,
          imageRect: imageRect,
          pageWidth: info.width.toDouble(),
          pageHeight: info.height.toDouble(),
          controller: controller,
          selection: _selection,
          layer: layer,
          highlights: _highlightsFor(page, layer, highlights),
          searchMark: mark != null && mark.page == page ? mark.range : null,
          onSelectionChanged: (range, viewport) =>
              _onSelectionChanged(page, range, viewport),
          onSelectionDragChanged: context
              .read<ReaderSelectionCubit>()
              .setAdjusting,
          handleColor: readerTextSelectionColorsOf(context).handle,
          onSelectionCleared: _onSelectionCleared,
          onHighlightPressed: _onHighlightPressed,
        );
      },
    );
  }
}
