part of 'reader_screen.dart';

/// Full-screen reader scaffold. The heavy WebView subtree is created only when
/// [ReaderBloc] reaches [ReaderStatus.ready].
class _ReaderView extends StatelessWidget {
  const _ReaderView({
    required this.serverPort,
    required this.textActions,
    this.onArticleTitlePressed,
  });

  final int serverPort;
  final List<TextAction> textActions;
  final void Function(String url, String title)? onArticleTitlePressed;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(
            child: BlocSelector<ReaderBloc, ReaderState, ReaderStatus>(
              selector: (state) => state.status,
              builder: (context, status) => _ReaderBody(
                status: status,
                serverPort: serverPort,
                textActions: textActions,
                onArticleTitlePressed: onArticleTitlePressed,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Switches between loading, failure, and ready reader content.
class _ReaderBody extends StatelessWidget {
  const _ReaderBody({
    required this.status,
    required this.serverPort,
    required this.textActions,
    this.onArticleTitlePressed,
  });

  final ReaderStatus status;
  final int serverPort;
  final List<TextAction> textActions;
  final void Function(String url, String title)? onArticleTitlePressed;

  @override
  Widget build(BuildContext context) {
    final readerTheme = ReaderThemePreset.fromId(
      context.select(
        (ReaderAppearanceCubit cubit) =>
            cubit.state.effectiveAppearance.themeId,
      ),
    ).data;

    return switch (status) {
      ReaderStatus.initial || ReaderStatus.loading => ColoredBox(
        color: readerTheme.backgroundColor,
        child: Center(child: _ReaderLoadingIndicator(theme: readerTheme)),
      ),
      ReaderStatus.failure => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(AppIcons.error, size: 48),
            const SizedBox(height: AppSpacing.md),
            const Text('Failed to load content'),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
      ReaderStatus.ready => _ReadyContent(
        serverPort: serverPort,
        textActions: textActions,
        onArticleTitlePressed: onArticleTitlePressed,
      ),
    };
  }
}

/// Ready-state wrapper that keeps the WebView and reader chrome together.
class _ReadyContent extends StatelessWidget {
  const _ReadyContent({
    required this.serverPort,
    required this.textActions,
    this.onArticleTitlePressed,
  });

  final int serverPort;
  final List<TextAction> textActions;
  final void Function(String url, String title)? onArticleTitlePressed;

  @override
  Widget build(BuildContext context) {
    return _ReadyContentBody(
      serverPort: serverPort,
      textActions: textActions,
      onArticleTitlePressed: onArticleTitlePressed,
    );
  }
}

/// Owns the WebView key and all imperative reader callbacks for ready content.
class _ReadyContentBody extends StatefulWidget {
  const _ReadyContentBody({
    required this.serverPort,
    required this.textActions,
    this.onArticleTitlePressed,
  });

  final int serverPort;
  final List<TextAction> textActions;
  final void Function(String url, String title)? onArticleTitlePressed;

  @override
  State<_ReadyContentBody> createState() => _ReadyContentBodyState();
}

class _ReadyContentBodyState extends State<_ReadyContentBody> {
  /// Imperative handle on the WebView so the progress slider can call
  /// `goToFraction(...)` directly on drag-end without bouncing through
  /// the bloc. Per-route key — the reader screen is recreated for each
  /// book open, so it's always fresh.
  final GlobalKey<BookReaderWebViewState> _webViewKey =
      GlobalKey<BookReaderWebViewState>();
  String? _webViewReadySourceId;

  void _seekFraction(double fraction) {
    context.read<ReaderUiCubit>().clearReaderSearch();
    _webViewKey.currentState?.goToFraction(fraction);
  }

  void _openTocDrawer() {
    context.read<ReaderUiCubit>().openTocDrawer();
  }

  void _closeTocDrawer({bool restoreChrome = true}) {
    _dismissReaderKeyboard();
    context.read<ReaderUiCubit>().closeTocDrawer(restoreChrome: restoreChrome);
  }

  void _openSearchDrawer() {
    context.read<ReaderUiCubit>().openSearchDrawer();
  }

  void _toggleBookmark() {
    _webViewKey.currentState?.toggleBookmark();
  }

  Future<void> _openAppearanceSheet() async {
    final uiCubit = context.read<ReaderUiCubit>();
    final appearanceCubit = context.read<ReaderAppearanceCubit>();
    final initialPageTurnStyle =
        appearanceCubit.state.effectiveAppearance.pageTurnStyle;
    final wasChromeVisible = uiCubit.state.chromeVisible;
    if (!uiCubit.beginAppearanceSheet()) return;
    if (wasChromeVisible) {
      await Future<void>.delayed(_kChromeAnimDuration);
      if (!mounted) return;
    }
    await showReaderAppearanceSheet(
      context,
      onFullyHidden: () {
        if (!mounted) return;
        final nextPageTurnStyle =
            appearanceCubit.state.effectiveAppearance.pageTurnStyle;
        uiCubit.appearanceSheetHidden();
        if (nextPageTurnStyle != initialPageTurnStyle) {
          uiCubit.showTapZoneHint(
            _readerTapAxisForPageTurnStyle(nextPageTurnStyle),
          );
        }
      },
    );
  }

  Future<void> _togglePageTurnStyle() async {
    final appearanceCubit = context.read<ReaderAppearanceCubit>();
    final uiCubit = context.read<ReaderUiCubit>();
    final current = appearanceCubit.state.effectiveAppearance.pageTurnStyle;
    final next = current == ReaderPageTurnStyle.vertical
        ? ReaderPageTurnStyle.horizontal
        : ReaderPageTurnStyle.vertical;
    await appearanceCubit.setPageTurnStyle(next);
    if (!mounted) return;
    uiCubit.showTapZoneHint(_readerTapAxisForPageTurnStyle(next));
  }

  void _closeSearchDrawer({
    bool restoreChrome = true,
    bool clearSearch = true,
  }) {
    _dismissReaderKeyboard();
    context.read<ReaderUiCubit>().closeSearchDrawer(
      restoreChrome: restoreChrome,
      clearSearch: clearSearch,
    );
  }

  void _dismissReaderKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _handleReaderPositionChanged(BookPosition position) {
    context.read<ReaderUiCubit>().readerPositionChanged(
      relocationReason: position.relocationReason,
    );
  }

  void _goToTocItem(ReaderTocItem item) {
    if (item.href.isEmpty) return;
    _webViewKey.currentState?.goToHref(item.href);
    _closeTocDrawer(restoreChrome: false);
  }

  void _goToBookmark(SourceBookmark bookmark) {
    if (bookmark.cfi.isEmpty) return;
    _webViewKey.currentState?.goToBookmark(
      cfi: bookmark.cfi,
      progress: bookmark.progress,
      anchorSectionIndex: bookmark.anchorSectionIndex,
      anchorSectionPage: bookmark.anchorSectionPage,
    );
    _closeTocDrawer(restoreChrome: false);
  }

  void _deleteBookmark(SourceBookmark bookmark) {
    context.read<ReaderBloc>().add(
      ReaderBookmarkChanged(
        remove: true,
        id: bookmark.id,
        cfi: bookmark.cfi,
        content: '',
        progress: bookmark.progress,
      ),
    );
  }

  void _goToSearchResult(ReaderSearchResult result) {
    if (result.cfi.isEmpty) return;
    context.read<ReaderSearchCubit>().resultSelected();
    context.read<ReaderUiCubit>().searchResultHighlightActivated();
    _webViewKey.currentState?.goToCfi(result.cfi);
    _closeSearchDrawer(restoreChrome: false, clearSearch: false);
  }

  Stream<ReaderSearchEvent> _searchBook(String query) {
    final readerState = context.read<ReaderBloc>().state;
    final searchEnabled = readerSearchActionEnabled(
      format: readerState.book?.format,
      documentFeatures: readerState.documentFeatures,
    );
    if (!searchEnabled) {
      return Stream.value(
        const ReaderSearchError(
          requestId: -1,
          message: 'Book search is unavailable',
        ),
      );
    }

    final webView = _webViewKey.currentState;
    if (webView == null) {
      return Stream.value(
        const ReaderSearchError(
          requestId: -1,
          message: 'Reader is not ready',
        ),
      );
    }
    return webView.searchBookStream(query);
  }

  void _clearDrawerSearch() {
    context.read<ReaderUiCubit>().clearReaderSearch();
  }

  @override
  Widget build(BuildContext context) {
    final appearance = context
        .select<ReaderAppearanceCubit, ReaderAppearancePreferences>(
          (c) => c.state.effectiveAppearance,
        );
    final pageProgressionRtl = context.select<ReaderBloc, bool>(
      (b) => b.state.pageProgressionRtl,
    );
    final format = context.select<ReaderBloc, BookFormat?>(
      (b) => b.state.book?.format,
    );
    final sourceId = context.select<ReaderBloc, String?>(
      (b) => b.state.sourceId,
    );
    final webViewReady = sourceId != null && _webViewReadySourceId == sourceId;
    // Reader theme drives the book *page* — WebView background and
    // foliate-js customCSS. Chrome (passed-through Stack siblings)
    // pulls colours from the app theme themselves; they don't take
    // a `readerTheme` prop any more.
    final readerTheme = ReaderThemePreset.fromId(appearance.themeId).data;
    _debugTraceReader(
      '_ReadyContentBody build '
      'sourceId=$sourceId '
      'webViewReady=$webViewReady '
      'format=$format '
      'theme=${appearance.themeId} '
      'layout=${appearance.layoutId}',
    );

    return _ReaderSystemUiOverlayDriver(
      readerTheme: readerTheme,
      child: BlocListener<ReaderUiCubit, ReaderUiState>(
        listenWhen: (previous, current) =>
            previous.clearSearchToken != current.clearSearchToken,
        listener: (_, _) => _webViewKey.currentState?.clearSearch(),
        child: Stack(
          children: [
            // WebView body — subscribes to `state.highlights` via
            // `context.select` so a TextAction such as Highlight fans changes
            // through to the WebView without forcing a reader reopen.
            ColoredBox(
              color: readerTheme.backgroundColor,
              child: _ReaderWebViewBody(
                sourceId: sourceId,
                serverPort: widget.serverPort,
                readerTheme: readerTheme,
                webViewKey: _webViewKey,
                onPositionChanged: _handleReaderPositionChanged,
                onReady: () {
                  if (!mounted) return;
                  final sourceId = context.read<ReaderBloc>().state.sourceId;
                  if (_webViewReadySourceId == sourceId) return;
                  setState(() => _webViewReadySourceId = sourceId);
                },
              ),
            ),
            ReaderTapZoneHintDriver(readerTheme: readerTheme),
            const _ReaderChromeDismissBarrierDriver(),
            _ReaderTapEdgeIndicatorDriver(
              readerTheme: readerTheme,
              appearance: appearance,
              visible: webViewReady,
            ),
            _ReaderTopChromeDriver(
              onArticleTitlePressed: widget.onArticleTitlePressed,
            ),
            const _ReaderPageBookmarkIndicatorDriver(),
            const ReaderBrightnessChromeDriver(),
            _ReaderBottomChromeDriver(
              onTocPressed: _openTocDrawer,
              onFontPressed: _openAppearanceSheet,
              onPageTurnPressed: _togglePageTurnStyle,
              onBookmarkPressed: _toggleBookmark,
              onSearchPressed: _openSearchDrawer,
              onSeekFraction: _seekFraction,
            ),
            const _ReaderImagePageProgressOverlayDriver(),
            _ContextPanelDriver(
              textActions: widget.textActions,
              webViewKey: _webViewKey,
            ),
            _ReaderTocDrawerVisibilityDriver(
              format: format,
              pageProgressionRtl: pageProgressionRtl,
              onClose: _closeTocDrawer,
              onItemSelected: _goToTocItem,
              onBookmarkSelected: _goToBookmark,
              onBookmarkDeleted: _deleteBookmark,
            ),
            _ReaderSearchDrawerVisibilityDriver(
              format: format,
              pageProgressionRtl: pageProgressionRtl,
              onClose: _closeSearchDrawer,
              onSearch: _searchBook,
              onClearSearch: _clearDrawerSearch,
              onResultSelected: _goToSearchResult,
            ),
          ],
        ),
      ),
    );
  }
}

/// Derives the platform status/navigation bar style from reader theme and
/// chrome visibility.
class _ReaderSystemUiOverlayDriver extends StatelessWidget {
  const _ReaderSystemUiOverlayDriver({
    required this.readerTheme,
    required this.child,
  });

  final ReaderThemeData readerTheme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final chromeVisible = context.select<ReaderUiCubit, bool>(
      (c) => c.state.chromeVisible,
    );
    final systemUiStyle = readerSystemUiOverlayStyle(
      readerTheme: readerTheme,
      chromeVisible: chromeVisible,
      chromeSurfaceColor: context.colors.surface,
      appNavigationBarColor: Theme.of(context).scaffoldBackgroundColor,
    );
    _debugTraceReader(
      '_ReaderSystemUiOverlayDriver build chrome=$chromeVisible',
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemUiStyle,
      child: child,
    );
  }
}

/// Subscribes only to TOC drawer visibility and forwards stable callbacks to
/// the drawer widget.
class _ReaderTocDrawerVisibilityDriver extends StatelessWidget {
  const _ReaderTocDrawerVisibilityDriver({
    required this.format,
    required this.pageProgressionRtl,
    required this.onClose,
    required this.onItemSelected,
    required this.onBookmarkSelected,
    required this.onBookmarkDeleted,
  });

  final BookFormat? format;
  final bool pageProgressionRtl;
  final void Function({bool restoreChrome}) onClose;
  final ValueChanged<ReaderTocItem> onItemSelected;
  final ValueChanged<SourceBookmark> onBookmarkSelected;
  final ValueChanged<SourceBookmark> onBookmarkDeleted;

  @override
  Widget build(BuildContext context) {
    final visible = context.select<ReaderUiCubit, bool>(
      (c) => c.state.overlay == ReaderOverlay.toc,
    );

    return _ReaderTocDrawerDriver(
      visible: visible,
      format: format,
      pageProgressionRtl: pageProgressionRtl,
      onClose: onClose,
      onItemSelected: onItemSelected,
      onBookmarkSelected: onBookmarkSelected,
      onBookmarkDeleted: onBookmarkDeleted,
    );
  }
}

/// Subscribes only to search drawer visibility and forwards search callbacks to
/// the drawer widget.
class _ReaderSearchDrawerVisibilityDriver extends StatelessWidget {
  const _ReaderSearchDrawerVisibilityDriver({
    required this.format,
    required this.pageProgressionRtl,
    required this.onClose,
    required this.onSearch,
    required this.onClearSearch,
    required this.onResultSelected,
  });

  final BookFormat? format;
  final bool pageProgressionRtl;
  final void Function({bool restoreChrome, bool clearSearch}) onClose;
  final Stream<ReaderSearchEvent> Function(String query) onSearch;
  final VoidCallback onClearSearch;
  final ValueChanged<ReaderSearchResult> onResultSelected;

  @override
  Widget build(BuildContext context) {
    final visible = context.select<ReaderUiCubit, bool>(
      (c) => c.state.overlay == ReaderOverlay.search,
    );

    return _ReaderSearchDrawer(
      visible: visible,
      format: format,
      pageProgressionRtl: pageProgressionRtl,
      onClose: onClose,
      onSearch: onSearch,
      onClearSearch: onClearSearch,
      onResultSelected: onResultSelected,
    );
  }
}

/// Builds the tap-zone edge indicator from reader direction, page bounds, and
/// appearance margins.
class _ReaderTapEdgeIndicatorDriver extends StatelessWidget {
  const _ReaderTapEdgeIndicatorDriver({
    required this.readerTheme,
    required this.appearance,
    required this.visible,
  });

  final ReaderThemeData readerTheme;
  final ReaderAppearancePreferences appearance;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final pageProgressionRtl = context.select<ReaderBloc, bool>(
      (b) => b.state.pageProgressionRtl,
    );
    final canGoPrevious = context.select<ReaderBloc, bool>(
      (b) => !b.state.atStart,
    );
    final canGoNext = context.select<ReaderBloc, bool>(
      (b) => !b.state.atEnd,
    );
    final layout = BookLayoutPreset.fromId(appearance.layoutId).data;
    _debugTraceReader(
      '_ReaderTapEdgeIndicatorDriver build '
      'visible=$visible '
      'rtl=$pageProgressionRtl '
      'canGoPrevious=$canGoPrevious '
      'canGoNext=$canGoNext '
      'pageTurn=${appearance.pageTurnStyle.id}',
    );

    return ReaderTapEdgeIndicator(
      readerTheme: readerTheme,
      axis: _readerTapAxisForPageTurnStyle(appearance.pageTurnStyle),
      pageProgressionRtl: pageProgressionRtl,
      canGoPrevious: canGoPrevious,
      canGoNext: canGoNext,
      contentTopMargin: layout.topMargin,
      contentBottomMargin: layout.bottomMargin,
      contentSideMargin: appearance.sideMargin,
      visible: visible,
    );
  }
}

/// Hosts the foliate WebView and translates WebView callbacks into reader bloc
/// and UI-cubit updates.
class _ReaderWebViewBody extends StatefulWidget {
  const _ReaderWebViewBody({
    required this.sourceId,
    required this.serverPort,
    required this.readerTheme,
    this.webViewKey,
    this.onPositionChanged,
    this.onReady,
  });

  final String? sourceId;
  final int serverPort;
  final ReaderThemeData readerTheme;

  /// Optional GlobalKey — the parent state holds it so progress chrome can
  /// reach into [BookReaderWebViewState] for `goToFraction`.
  final GlobalKey<BookReaderWebViewState>? webViewKey;

  /// Side-effect hook for UI-only reader chrome state. Bloc persistence stays
  /// inside this widget; parent uses this to clear transient search overlays.
  final ValueChanged<BookPosition>? onPositionChanged;

  final VoidCallback? onReady;

  @override
  State<_ReaderWebViewBody> createState() => _ReaderWebViewBodyState();
}

class _ReaderWebViewBodyState extends State<_ReaderWebViewBody> {
  /// `true` once foliate-js has fired its `onLoadEnd` callback — at that
  /// point the WebView has the book parsed and the first page painted.
  /// Until then we cover the (visually empty) WebView with a loading
  /// scrim so the user gets feedback that the tap registered.
  bool _foliateReady = false;

  /// Memoization for the domain → bridge highlight mapping. This widget
  /// rebuilds for many reasons unrelated to highlights (chrome tap,
  /// font/layout change in ReaderAppearanceCubit, the loading-scrim flip,
  /// etc.); without a cache the `.map(...).toList()` re-allocates the
  /// `ReaderHighlight` list every time.
  ///
  /// Cache lives on the widget state (not on `ReaderState`) on purpose.
  /// `ReaderState` instances churn on every page-turn via `copyWith`,
  /// which would invalidate a `late final` cache on each tick. The
  /// underlying `state.highlights` reference, in contrast, only
  /// changes on `ReaderHighlightsRefreshed` — so widget-state cache
  /// keyed on `identical(...)` of that reference and the reader theme
  /// hits on every non-highlights, non-theme rebuild.
  List<Highlight>? _lastHighlightsRef;
  ReaderThemeData? _lastHighlightsTheme;
  List<ReaderHighlight>? _cachedReaderHighlights;
  List<SourceBookmark>? _lastBookmarksRef;
  List<ReaderBookmark>? _cachedReaderBookmarks;

  @override
  void didUpdateWidget(covariant _ReaderWebViewBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    final sourceChanged = oldWidget.sourceId != widget.sourceId;
    final themeChanged = oldWidget.readerTheme != widget.readerTheme;
    if (sourceChanged || themeChanged) {
      _debugTraceReader(
        '_ReaderWebViewBody didUpdateWidget '
        'sourceChanged=$sourceChanged '
        'themeChanged=$themeChanged',
      );
    }
    if (oldWidget.sourceId != widget.sourceId) {
      _foliateReady = false;
    }
  }

  List<ReaderHighlight> _readerHighlightsFor(
    List<Highlight> source,
    ReaderThemeData theme,
  ) {
    final cached = _cachedReaderHighlights;
    if (cached != null &&
        identical(source, _lastHighlightsRef) &&
        _lastHighlightsTheme == theme) {
      return cached;
    }
    _lastHighlightsRef = source;
    _lastHighlightsTheme = theme;
    return _cachedReaderHighlights = [
      for (final h in source)
        ReaderHighlight(
          id: h.id,
          text: h.text,
          cfiRange: h.cfiRange,
          color: readerHighlightCssColor(h.color, theme),
        ),
    ];
  }

  List<ReaderBookmark> _readerBookmarksFor(List<SourceBookmark> source) {
    final cached = _cachedReaderBookmarks;
    if (cached != null && identical(source, _lastBookmarksRef)) {
      return cached;
    }
    _lastBookmarksRef = source;
    return _cachedReaderBookmarks = [
      for (final bookmark in source)
        ReaderBookmark(
          id: bookmark.id,
          cfi: bookmark.cfi,
          progress: bookmark.progress,
          content: bookmark.content,
          anchorExact: bookmark.anchorExact,
          anchorPrefix: bookmark.anchorPrefix,
          anchorSuffix: bookmark.anchorSuffix,
          anchorSectionIndex: bookmark.anchorSectionIndex,
          anchorSectionPage: bookmark.anchorSectionPage,
        ),
    ];
  }

  /// Memoization for `buildBookCustomCSS`. The CSS string only depends on
  /// the reader theme. Reader themes are value-equatable, so we cache
  /// the latest value and reuse the string
  /// across rebuilds triggered by chrome/highlight/scrim emits — those
  /// don't change this input but used to re-run the StringBuffer build
  /// every frame.
  String? _cachedCustomCSS;
  ReaderThemeData? _lastCssTheme;

  String _customCSSFor(ReaderThemeData theme) {
    final cached = _cachedCustomCSS;
    if (cached != null && _lastCssTheme == theme) {
      return cached;
    }
    _lastCssTheme = theme;
    return _cachedCustomCSS = buildBookCustomCSS(
      theme: theme,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ReaderBloc>();
    final uiCubit = context.read<ReaderUiCubit>();
    final selectionCubit = context.read<ReaderSelectionCubit>();
    final highlightFocusCubit = context.read<ReaderHighlightFocusCubit>();
    // Subscribe specifically to the highlights list. `state.highlights`
    // is a fresh list instance only on `ReaderHighlightsRefreshed`
    // emits — page turns and other state changes preserve the same
    // reference, so those don't trigger a rebuild.
    final highlightsState = context.select<ReaderBloc, List<Highlight>>(
      (b) => b.state.highlights,
    );
    final bookmarksState = context.select<ReaderBloc, List<SourceBookmark>>(
      (b) => b.state.bookmarks,
    );
    final state = bloc.state;
    final highlights = _readerHighlightsFor(
      highlightsState,
      widget.readerTheme,
    );
    final bookmarks = _readerBookmarksFor(bookmarksState);
    final appearance = context
        .select<ReaderAppearanceCubit, ReaderAppearancePreferences>(
          (c) => c.state.effectiveAppearance,
        );
    _debugTraceReader(
      '_ReaderWebViewBody build '
      'sourceId=${state.sourceId} '
      'foliateReady=$_foliateReady '
      'progress=${state.book?.readingProgress.toStringAsFixed(3)} '
      'highlights=${highlights.length} '
      'bookmarks=${bookmarks.length} '
      'theme=${appearance.themeId} '
      'layout=${appearance.layoutId} '
      'pageTurn=${appearance.pageTurnStyle.id}',
    );

    final tapAxis = _readerTapAxisForPageTurnStyle(appearance.pageTurnStyle);

    void onTapped(double x, double y) {
      highlightFocusCubit.clear();
      switch (readerTapCommandFor(
        x: x,
        y: y,
        chromeVisible: uiCubit.state.chromeVisible,
        axis: tapAxis,
      )) {
        case ReaderTapCommand.physicalLeftPage:
          widget.webViewKey?.currentState?.pageLeft();
        case ReaderTapCommand.physicalRightPage:
          widget.webViewKey?.currentState?.pageRight();
        case ReaderTapCommand.previousPage:
          widget.webViewKey?.currentState?.prevPage();
        case ReaderTapCommand.nextPage:
          widget.webViewKey?.currentState?.nextPage();
        case ReaderTapCommand.toggleChrome:
          uiCubit.toggleChrome();
      }
    }

    final fontPreset = ReaderFontPreset.fromId(appearance.fontId);
    final layout = BookLayoutPreset.fromId(appearance.layoutId).data;
    final deviceFontScale = readerDeviceFontScale(
      platform: Theme.of(context).platform,
      viewportSize: MediaQuery.sizeOf(context),
    );
    final customCSS = _customCSSFor(widget.readerTheme);

    final readerSurface = BookReaderWebView(
      // Parent's GlobalKey when provided (lets progress chrome seek
      // imperatively). Falls back to source-id ValueKey for forced
      // remount on book change.
      key: widget.webViewKey ?? ValueKey(state.sourceId),
      serverPort: widget.serverPort,
      bookFilePath: state.book!.filePath,
      initialCfi: state.book?.currentCfi,
      initialProgress: state.book?.readingProgress,
      foliateStyle: FoliateStyle(
        fontName: fontPreset.fontFamily,
        fontPath:
            'http://127.0.0.1:${widget.serverPort}'
            '/assets/fonts/${fontPreset.fontFile}',
        // `fontSize` is the device-adjusted baseline. User A-/A+ zoom is
        // passed separately as `textScale` so code/pre blocks can stay on
        // the stable baseline while prose grows.
        fontSize: layout.fontSize * deviceFontScale,
        textScale: appearance.textScale,
        deviceFontScale: deviceFontScale,
        fontWeight: layout.fontWeight,
        letterSpacing: layout.letterSpacing,
        spacing: appearance.lineHeight,
        paragraphSpacing: layout.paragraphSpacing,
        textIndent: layout.textIndent,
        topMargin: layout.topMargin,
        bottomMargin: layout.bottomMargin,
        sideMargin: appearance.sideMargin,
        justify: appearance.textAlignment == ReaderTextAlignment.justify,
        hyphenate: layout.hyphenate,
        textAlign: appearance.textAlignment.id,
        pageTurnStyle: appearance.pageTurnStyle.id,
        fontColor: colorToHex(widget.readerTheme.primaryTextColor),
        backgroundColor: colorToHex(widget.readerTheme.backgroundColor),
        accentColor: colorToHex(context.colors.primary),
        customCSS: customCSS,
        customCSSEnabled: true,
        overrideFont: appearance.overrideFont,
        overrideColor: appearance.overrideColor,
        useBookLayout: appearance.useBookLayout,
        // Force single-column pagination. foliate-js's default is
        // a max of 2 columns on wide viewports (landscape iPhone,
        // tablets), which makes `bookCurrentPage` increment by 2
        // on each page-turn — confusing for users who expect every
        // tap to advance the counter by one. When/if a tablet
        // reading layout is wanted, expose this through the reader
        // appearance preference instead of hard-coding here.
        maxColumnCount: 1,
      ),
      isArticle: state.sourceType == SourceType.article,
      pageProgressionRtl: state.pageProgressionRtl,
      highlights: highlights,
      bookmarks: bookmarks,
      onReady: () {
        if (mounted && !_foliateReady) {
          _debugTraceReader('_ReaderWebViewBody onReady');
          setState(() => _foliateReady = true);
          widget.onReady?.call();
        }
      },
      onPositionChanged: (position) {
        _debugTraceReader(
          '_ReaderWebViewBody onPositionChanged '
          'progress=${position.fraction.toStringAsFixed(3)} '
          'bookPage=${position.bookCurrentPage}/${position.bookTotalPages} '
          'chapterPage=${position.chapterCurrentPage}/'
          '${position.chapterTotalPages} '
          'atStart=${position.atStart} '
          'atEnd=${position.atEnd}',
        );
        bloc.add(
          ReaderBookPositionUpdated(
            cfi: position.cfi,
            progress: position.fraction,
            chapterTitle: position.chapterTitle,
            bookCurrentPage: position.bookCurrentPage,
            bookTotalPages: position.bookTotalPages,
            chapterCurrentPage: position.chapterCurrentPage,
            chapterTotalPages: position.chapterTotalPages,
            sizeTotal: position.sizeTotal,
            pageProgressionRtl: position.pageProgressionRtl,
            atStart: position.atStart,
            atEnd: position.atEnd,
            currentPageBookmarked: position.bookmarkExists,
            currentPageBookmarkCfi: position.bookmarkCfi,
            currentPageBookmarkId: position.bookmarkId,
          ),
        );
        widget.onPositionChanged?.call(position);
      },
      onTocChanged: (items) {
        bloc.add(ReaderTocUpdated(items: items));
      },
      onDocumentFeaturesChanged: (features) {
        bloc.add(ReaderDocumentFeaturesUpdated(features: features));
      },
      onBookmarkChanged: (change) {
        bloc.add(
          ReaderBookmarkChanged(
            remove: change.remove,
            id: change.id,
            cfi: change.cfi,
            content: change.content,
            progress: change.progress,
            anchorExact: change.anchorExact,
            anchorPrefix: change.anchorPrefix,
            anchorSuffix: change.anchorSuffix,
            anchorSectionIndex: change.anchorSectionIndex,
            anchorSectionPage: change.anchorSectionPage,
          ),
        );
      },
      onTextSelected: (selection) {
        highlightFocusCubit.clear();
        if (isImagePageFormat(bloc.state.book?.format)) {
          selectionCubit.deselect();
          widget.webViewKey?.currentState?.clearSelection();
          return;
        }
        uiCubit.hideChrome();
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
        );
      },
      onTextDeselected: () => selectionCubit.deselect(),
      onHighlightTapped: (tap) {
        uiCubit.hideChrome();
        selectionCubit.deselect();
        widget.webViewKey?.currentState?.clearSelection();
        highlightFocusCubit.focus(tap);
      },
      onTapped: onTapped,
    );

    return Stack(
      children: [
        Positioned.fill(child: readerSurface),
        // Loading scrim — covers the WebView while it's still mounting and
        // foliate-js is parsing the book. Background uses the reader
        // theme so it blends seamlessly into the rendered book once the
        // scrim fades. Fades out after `onReady` so the transition feels
        // intentional, not a flash.
        //
        // Centered spinner instead of a top-edge bar: the reader route
        // is opened with a full-screen vertical slide transition, and a
        // top-edge bar reads as «sliding up» during that animation. A
        // centered circular indicator doesn't fight the route transition.
        IgnorePointer(
          ignoring: _foliateReady,
          child: AnimatedOpacity(
            opacity: _foliateReady ? 0 : 1,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            child: ColoredBox(
              color: widget.readerTheme.backgroundColor,
              child: Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: _ReaderLoadingIndicator(theme: widget.readerTheme),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReaderLoadingIndicator extends StatelessWidget {
  const _ReaderLoadingIndicator({required this.theme});

  final ReaderThemeData theme;

  @override
  Widget build(BuildContext context) {
    return CircularProgressIndicator(
      strokeWidth: 2.4,
      backgroundColor: readerLoadingIndicatorTrackColor(theme),
      valueColor: AlwaysStoppedAnimation<Color>(
        readerLoadingIndicatorColor(theme),
      ),
    );
  }
}
