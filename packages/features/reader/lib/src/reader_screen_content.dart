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
      body: ReaderRouteMountGate(
        delay: _kReaderWebViewRouteMountDelay,
        builder: (context, canMountWebView) {
          return Stack(
            children: [
              Positioned.fill(
                child: BlocSelector<ReaderBloc, ReaderState, ReaderStatus>(
                  selector: (state) => state.status,
                  builder: (context, status) => _ReaderBody(
                    status: status,
                    canMountWebView: canMountWebView,
                    serverPort: serverPort,
                    textActions: textActions,
                    onArticleTitlePressed: onArticleTitlePressed,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Switches between loading, failure, and ready reader content.
class _ReaderBody extends StatefulWidget {
  const _ReaderBody({
    required this.status,
    required this.canMountWebView,
    required this.serverPort,
    required this.textActions,
    this.onArticleTitlePressed,
  });

  final ReaderStatus status;
  final bool canMountWebView;
  final int serverPort;
  final List<TextAction> textActions;
  final void Function(String url, String title)? onArticleTitlePressed;

  @override
  State<_ReaderBody> createState() => _ReaderBodyState();
}

class _ReaderBodyState extends State<_ReaderBody> {
  String? _readyWebViewSourceId;

  void _handleWebViewReady(String? sourceId) {
    if (_readyWebViewSourceId == sourceId) return;
    setState(() => _readyWebViewSourceId = sourceId);
  }

  @override
  Widget build(BuildContext context) {
    final readerTheme = ReaderThemePreset.fromId(
      context.select(
        (ReaderAppearanceCubit cubit) =>
            cubit.state.effectiveAppearance.themeId,
      ),
    ).data;
    final sourceId = context.select<ReaderBloc, String?>(
      (bloc) => bloc.state.sourceId,
    );
    final contentReady =
        widget.status == ReaderStatus.ready && widget.canMountWebView;
    final webViewReady = sourceId != null && _readyWebViewSourceId == sourceId;
    final loadingVisible =
        widget.status == ReaderStatus.initial ||
        widget.status == ReaderStatus.loading ||
        (widget.status == ReaderStatus.ready && !webViewReady);

    return Stack(
      children: [
        Positioned.fill(
          child: switch (widget.status) {
            ReaderStatus.failure => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(AppIcons.error, size: 48),
                  const SizedBox(height: AppSpacing.md),
                  Text(context.l10n.readerFailedToLoadContent),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(context.l10n.readerGoBack),
                  ),
                ],
              ),
            ),
            ReaderStatus.ready when contentReady => _ReadyContent(
              serverPort: widget.serverPort,
              textActions: widget.textActions,
              onArticleTitlePressed: widget.onArticleTitlePressed,
              onWebViewReady: _handleWebViewReady,
            ),
            ReaderStatus.initial ||
            ReaderStatus.loading ||
            ReaderStatus.ready => const SizedBox.expand(),
          },
        ),
        IgnorePointer(
          ignoring: !loadingVisible,
          child: AnimatedOpacity(
            opacity: loadingVisible ? 1 : 0,
            duration: _kReaderLoadingScrimFadeDuration,
            curve: Curves.easeOutCubic,
            child: _ReaderLoadingScrim(theme: readerTheme),
          ),
        ),
      ],
    );
  }
}

/// Ready-state wrapper that keeps the WebView and reader chrome together.
class _ReadyContent extends StatelessWidget {
  const _ReadyContent({
    required this.serverPort,
    required this.textActions,
    required this.onWebViewReady,
    this.onArticleTitlePressed,
  });

  final int serverPort;
  final List<TextAction> textActions;
  final ValueChanged<String?> onWebViewReady;
  final void Function(String url, String title)? onArticleTitlePressed;

  @override
  Widget build(BuildContext context) {
    return _ReadyContentBody(
      serverPort: serverPort,
      textActions: textActions,
      onArticleTitlePressed: onArticleTitlePressed,
      onWebViewReady: onWebViewReady,
    );
  }
}

/// Owns the WebView key and all imperative reader callbacks for ready content.
class _ReadyContentBody extends StatefulWidget {
  const _ReadyContentBody({
    required this.serverPort,
    required this.textActions,
    required this.onWebViewReady,
    this.onArticleTitlePressed,
  });

  final int serverPort;
  final List<TextAction> textActions;
  final ValueChanged<String?> onWebViewReady;
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
  final GlobalKey<ArticleHtmlReaderWebViewState> _articleWebViewKey =
      GlobalKey<ArticleHtmlReaderWebViewState>();
  String? _webViewReadySourceId;

  void _seekFraction(double fraction) {
    context.read<ReaderUiCubit>().clearReaderSearch();
    final sourceType = context.read<ReaderBloc>().state.sourceType;
    if (sourceType == SourceType.article) {
      _articleWebViewKey.currentState?.goToFraction(fraction);
      return;
    }
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
    if (context.read<ReaderBloc>().state.sourceType == SourceType.article) {
      _articleWebViewKey.currentState?.toggleBookmark();
      return;
    }
    _webViewKey.currentState?.toggleBookmark();
  }

  Future<void> _openAppearanceSheet() async {
    final uiCubit = context.read<ReaderUiCubit>();
    final appearanceCubit = context.read<ReaderAppearanceCubit>();
    final sourceType = context.read<ReaderBloc>().state.sourceType;
    final showPageTurnControls = sourceType != SourceType.article;
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
      showPageTurnControls: showPageTurnControls,
      onFullyHidden: () {
        if (!mounted) return;
        final nextPageTurnStyle =
            appearanceCubit.state.effectiveAppearance.pageTurnStyle;
        uiCubit.appearanceSheetHidden();
        if (showPageTurnControls && nextPageTurnStyle != initialPageTurnStyle) {
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
    if (context.read<ReaderBloc>().state.sourceType == SourceType.article) {
      _articleWebViewKey.currentState?.goToHref(item.href);
    } else {
      _webViewKey.currentState?.goToHref(item.href);
    }
    _closeTocDrawer(restoreChrome: false);
  }

  void _goToBookmark(SourceBookmark bookmark) {
    if (bookmark.cfi.isEmpty) return;
    if (context.read<ReaderBloc>().state.sourceType == SourceType.article) {
      _articleWebViewKey.currentState?.goToBookmark(
        cfi: bookmark.cfi,
        progress: bookmark.progress,
      );
      _closeTocDrawer(restoreChrome: false);
      return;
    }
    _webViewKey.currentState?.goToBookmark(
      cfi: bookmark.cfi,
      progress: bookmark.progress,
      anchorSectionIndex: bookmark.anchorSectionIndex,
      anchorSectionPage: bookmark.anchorSectionPage,
    );
    _closeTocDrawer(restoreChrome: false);
  }

  void _goToHighlight(Highlight highlight) {
    final imageArea = highlight.imageArea;
    if (imageArea != null) {
      _webViewKey.currentState?.goToSectionIndex(imageArea.pageIndex);
      _closeTocDrawer(restoreChrome: false);
      return;
    }
    final cfiRange = highlight.cfiRange;
    if (cfiRange == null || cfiRange.isEmpty) return;
    _webViewKey.currentState?.goToCfi(cfiRange);
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
    if (context.read<ReaderBloc>().state.sourceType == SourceType.article) {
      _articleWebViewKey.currentState?.goToSearchResult(result.cfi);
      _closeSearchDrawer(restoreChrome: false, clearSearch: false);
      return;
    }
    _webViewKey.currentState?.goToSearchResult(result.cfi);
    _closeSearchDrawer(restoreChrome: false, clearSearch: false);
  }

  Stream<ReaderSearchEvent> _searchBook(String query) {
    final readerState = context.read<ReaderBloc>().state;
    final searchEnabled = readerSearchActionEnabled(
      format: readerState.document?.format,
      documentFeatures: readerState.documentFeatures,
    );
    if (!searchEnabled) {
      return Stream.value(
        ReaderSearchError(
          requestId: -1,
          message: context.l10n.readerBookSearchUnavailable,
        ),
      );
    }

    if (readerState.sourceType == SourceType.article) {
      final webView = _articleWebViewKey.currentState;
      if (webView == null) {
        return Stream.value(
          ReaderSearchError(
            requestId: -1,
            message: context.l10n.readerNotReady,
          ),
        );
      }
      return webView.searchBookStream(query);
    }

    final webView = _webViewKey.currentState;
    if (webView == null) {
      return Stream.value(
        ReaderSearchError(
          requestId: -1,
          message: context.l10n.readerNotReady,
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
      (b) => b.state.document?.format,
    );
    final sourceType = context.select<ReaderBloc, SourceType>(
      (b) => b.state.sourceType,
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
        listener: (_, _) {
          _webViewKey.currentState?.clearSearch();
          _articleWebViewKey.currentState?.clearSearch();
        },
        child: Stack(
          children: [
            // WebView body — subscribes to `state.highlights` via
            // `context.select` so a TextAction such as Highlight fans changes
            // through to the WebView without forcing a reader reopen.
            ColoredBox(
              color: readerTheme.backgroundColor,
              child: sourceType == SourceType.article
                  ? _ReaderArticleHtmlBody(
                      sourceId: sourceId,
                      serverPort: widget.serverPort,
                      readerTheme: readerTheme,
                      webViewKey: _articleWebViewKey,
                      onPositionChanged: _handleReaderPositionChanged,
                      onReady: () {
                        if (!mounted) return;
                        final sourceId = context
                            .read<ReaderBloc>()
                            .state
                            .sourceId;
                        if (_webViewReadySourceId == sourceId) return;
                        setState(() => _webViewReadySourceId = sourceId);
                        widget.onWebViewReady(sourceId);
                      },
                    )
                  : _ReaderWebViewBody(
                      sourceId: sourceId,
                      serverPort: widget.serverPort,
                      readerTheme: readerTheme,
                      webViewKey: _webViewKey,
                      onPositionChanged: _handleReaderPositionChanged,
                      onReady: () {
                        if (!mounted) return;
                        final sourceId = context
                            .read<ReaderBloc>()
                            .state
                            .sourceId;
                        if (_webViewReadySourceId == sourceId) return;
                        setState(() => _webViewReadySourceId = sourceId);
                        widget.onWebViewReady(sourceId);
                      },
                    ),
            ),
            const _ReaderBrightnessDimmingOverlayDriver(),
            ReaderTapZoneHintDriver(readerTheme: readerTheme),
            const _ReaderChromeDismissBarrierDriver(),
            _ReaderTapEdgeIndicatorDriver(
              readerTheme: readerTheme,
              appearance: appearance,
              visible: webViewReady && sourceType != SourceType.article,
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
              readerTheme: readerTheme,
              onClose: _closeTocDrawer,
              onItemSelected: _goToTocItem,
              onBookmarkSelected: _goToBookmark,
              onHighlightSelected: _goToHighlight,
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

/// Applies reader-local dimming when Android cannot lower per-window
/// brightness predictably from the current system level.
class _ReaderBrightnessDimmingOverlayDriver extends StatelessWidget {
  const _ReaderBrightnessDimmingOverlayDriver();

  @override
  Widget build(BuildContext context) {
    final opacity = context.select<ReaderBrightnessCubit, double>(
      (c) => c.state.dimmingOpacity,
    );

    return Positioned.fill(
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(end: opacity),
          duration: _kReaderBrightnessDimmingDuration,
          curve: Curves.easeOutCubic,
          builder: (_, value, _) {
            return ColoredBox(
              color: Colors.black.withValues(alpha: value),
            );
          },
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
    required this.readerTheme,
    required this.onClose,
    required this.onItemSelected,
    required this.onBookmarkSelected,
    required this.onHighlightSelected,
    required this.onBookmarkDeleted,
  });

  final BookFormat? format;
  final bool pageProgressionRtl;
  final ReaderThemeData readerTheme;
  final void Function({bool restoreChrome}) onClose;
  final ValueChanged<ReaderTocItem> onItemSelected;
  final ValueChanged<SourceBookmark> onBookmarkSelected;
  final ValueChanged<Highlight> onHighlightSelected;
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
      readerTheme: readerTheme,
      onClose: onClose,
      onItemSelected: onItemSelected,
      onBookmarkSelected: onBookmarkSelected,
      onHighlightSelected: onHighlightSelected,
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

FoliateStyle _readerWebViewStyle({
  required BuildContext context,
  required int serverPort,
  required ReaderAppearancePreferences appearance,
  required ReaderThemeData readerTheme,
  double? topMargin,
  double? bottomMargin,
  String customCSS = '',
}) {
  final fontPreset = ReaderFontPreset.fromId(appearance.fontId);
  final layout = BookLayoutPreset.fromId(appearance.layoutId).data;
  final mediaPadding = MediaQuery.paddingOf(context);
  final deviceFontScale = readerDeviceFontScale(
    platform: Theme.of(context).platform,
    viewportSize: MediaQuery.sizeOf(context),
  );

  return FoliateStyle(
    fontName: fontPreset.fontFamily,
    fontPath:
        'http://127.0.0.1:$serverPort/assets/fonts/${fontPreset.fontFile}',
    fontSize: layout.fontSize * deviceFontScale,
    textScale: appearance.textScale,
    deviceFontScale: deviceFontScale,
    fontWeight: layout.fontWeight,
    letterSpacing: layout.letterSpacing,
    spacing: appearance.lineHeight,
    paragraphSpacing: layout.paragraphSpacing,
    textIndent: layout.textIndent,
    topMargin: topMargin ?? layout.topMargin,
    bottomMargin: bottomMargin ?? layout.bottomMargin,
    safeAreaTop: mediaPadding.top,
    safeAreaBottom: mediaPadding.bottom,
    sideMargin: appearance.sideMargin,
    justify: appearance.textAlignment == ReaderTextAlignment.justify,
    hyphenate: layout.hyphenate,
    textAlign: appearance.textAlignment.id,
    pageTurnStyle: appearance.pageTurnStyle.id,
    fontColor: colorToHex(readerTheme.primaryTextColor),
    backgroundColor: colorToHex(readerTheme.backgroundColor),
    accentColor: colorToHex(context.colors.primary),
    customCSS: customCSS,
    customCSSEnabled: customCSS.isNotEmpty,
    overrideFont: appearance.overrideFont,
    overrideColor: appearance.overrideColor,
    useBookLayout: appearance.useBookLayout,
    maxColumnCount: 1,
  );
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
          imagePageIndex: h.imageArea?.pageIndex,
          imageArea: _readerImageAreaFor(h.imageArea),
          color: readerHighlightCssColor(h.color, theme),
          opacity: readerHighlightOpacity(theme),
          mixBlendMode: readerHighlightBlendMode(theme),
          verticalOffset: readerHighlightVerticalOffset(theme),
        ),
    ];
  }

  ReaderImageAreaRect? _readerImageAreaFor(HighlightImageArea? area) {
    if (area == null) return null;
    return ReaderImageAreaRect(
      x: area.x,
      y: area.y,
      width: area.width,
      height: area.height,
    );
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
    final imageSelectionCubit = context.read<ReaderImageSelectionCubit>();
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
      'progress=${state.document?.readingProgress.toStringAsFixed(3)} '
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

    final customCSS = _customCSSFor(widget.readerTheme);
    final foliateStyle = _readerWebViewStyle(
      context: context,
      serverPort: widget.serverPort,
      appearance: appearance,
      readerTheme: widget.readerTheme,
      customCSS: customCSS,
    );

    final readerSurface = BookReaderWebView(
      // Parent's GlobalKey when provided (lets progress chrome seek
      // imperatively). Falls back to source-id ValueKey for forced
      // remount on book change.
      key: widget.webViewKey ?? ValueKey(state.sourceId),
      serverPort: widget.serverPort,
      bookFilePath: state.document!.filePath,
      initialCfi: state.document?.currentCfi,
      initialProgress: state.document?.readingProgress,
      foliateStyle: foliateStyle,
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
        imageSelectionCubit.deselect();
        final currentState = bloc.state;
        if (isImagePageFormat(currentState.document?.format)) {
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
          progress: currentState.document?.readingProgress,
          chapterTitle: currentState.chapterTitle,
          containedHighlightIds: selection.containedHighlightIds,
        );
      },
      onImageAreaSelected: (selection) {
        final currentState = bloc.state;
        if (!isImagePageFormat(currentState.document?.format)) return;
        highlightFocusCubit.clear();
        selectionCubit.deselect();
        uiCubit.hideChrome();
        imageSelectionCubit.select(
          pageIndex: selection.pageIndex,
          rect: selection.rect,
          position: selection.position,
          progress: currentState.document?.readingProgress,
          chapterTitle: currentState.chapterTitle,
        );
      },
      onTextDeselected: () {
        if (imageSelectionCubit.consumeProtectedClear()) return;
        selectionCubit.deselect();
        imageSelectionCubit.deselect();
      },
      onHighlightTapped: (tap) {
        uiCubit.hideChrome();
        selectionCubit.deselect();
        imageSelectionCubit.deselect();
        widget.webViewKey?.currentState?.clearSelection();
        highlightFocusCubit.focus(tap);
      },
      onTapped: onTapped,
    );

    return readerSurface;
  }
}

/// Hosts the vertical HTML article WebView and translates scroll callbacks into
/// the same reader bloc position contract used by book formats.
class _ReaderArticleHtmlBody extends StatefulWidget {
  const _ReaderArticleHtmlBody({
    required this.sourceId,
    required this.serverPort,
    required this.readerTheme,
    required this.webViewKey,
    this.onPositionChanged,
    this.onReady,
  });

  final String? sourceId;
  final int serverPort;
  final ReaderThemeData readerTheme;
  final GlobalKey<ArticleHtmlReaderWebViewState> webViewKey;
  final ValueChanged<BookPosition>? onPositionChanged;
  final VoidCallback? onReady;

  @override
  State<_ReaderArticleHtmlBody> createState() => _ReaderArticleHtmlBodyState();
}

class _ReaderArticleHtmlBodyState extends State<_ReaderArticleHtmlBody> {
  bool _htmlReady = false;
  List<SourceBookmark>? _lastBookmarksRef;
  List<ReaderBookmark>? _cachedReaderBookmarks;

  @override
  void didUpdateWidget(covariant _ReaderArticleHtmlBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sourceId != widget.sourceId) {
      _htmlReady = false;
    }
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
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ReaderBloc>();
    final uiCubit = context.read<ReaderUiCubit>();
    final state = bloc.state;
    final bookmarksState = context.select<ReaderBloc, List<SourceBookmark>>(
      (b) => b.state.bookmarks,
    );
    final bookmarks = _readerBookmarksFor(bookmarksState);
    final appearance = context
        .select<ReaderAppearanceCubit, ReaderAppearancePreferences>(
          (c) => c.state.effectiveAppearance,
        );
    final customCSS = buildBookCustomCSS(theme: widget.readerTheme);
    final articleStyle = _readerWebViewStyle(
      context: context,
      serverPort: widget.serverPort,
      appearance: appearance,
      readerTheme: widget.readerTheme,
      topMargin: _kArticleReaderTopMargin,
      bottomMargin: _kArticleReaderBottomMargin,
      customCSS: customCSS,
    );

    final readerSurface = ArticleHtmlReaderWebView(
      key: widget.webViewKey,
      serverPort: widget.serverPort,
      articleFilePath: state.document!.filePath,
      initialPosition: state.document?.currentCfi,
      initialProgress: state.document?.readingProgress,
      foliateStyle: articleStyle,
      bookmarks: bookmarks,
      onReady: () {
        if (mounted && !_htmlReady) {
          setState(() => _htmlReady = true);
          widget.onReady?.call();
        }
      },
      onPositionChanged: (position) {
        _debugTraceReader(
          '_ReaderArticleHtmlBody onPositionChanged '
          'progress=${position.fraction.toStringAsFixed(3)} '
          'chapter=${position.chapterTitle} '
          'atStart=${position.atStart} '
          'atEnd=${position.atEnd}',
        );
        bloc.add(
          ReaderBookPositionUpdated(
            cfi: position.cfi,
            progress: position.fraction,
            chapterTitle: position.chapterTitle,
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
          ),
        );
      },
      onTapped: (_, _) {
        uiCubit.toggleChrome();
      },
    );

    return Stack(
      children: [
        Positioned.fill(child: readerSurface),
        Positioned.fill(
          child: _ArticleSystemBarBackground(
            color: widget.readerTheme.backgroundColor,
          ),
        ),
      ],
    );
  }
}

/// Paints only the unsafe top inset so article text stays readable without
/// adding decorative fades or bottom overlays over the content.
class _ArticleSystemBarBackground extends StatelessWidget {
  const _ArticleSystemBarBackground({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return IgnorePointer(
      child: Stack(
        children: [
          if (padding.top > 0)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: padding.top,
              child: ColoredBox(color: color),
            ),
        ],
      ),
    );
  }
}

class _ReaderLoadingMark extends StatelessWidget {
  const _ReaderLoadingMark({required this.theme});

  final ReaderThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Icon(
      AppIcons.book,
      size: _kReaderLoadingIconSize,
      color: theme.primaryTextColor.withValues(alpha: 0.82),
    );
  }
}

class _ReaderLoadingScrim extends StatelessWidget {
  const _ReaderLoadingScrim({required this.theme});

  final ReaderThemeData theme;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: theme.backgroundColor,
      child: Center(
        child: SizedBox.square(
          dimension: _kReaderLoadingIconSize,
          child: _ReaderLoadingMark(theme: theme),
        ),
      ),
    );
  }
}
