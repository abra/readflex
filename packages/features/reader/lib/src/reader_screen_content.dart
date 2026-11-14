import 'dart:async';

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:shared/shared.dart';
import 'package:toast_service/toast_service.dart';

import 'reader_appearance_cubit.dart';
import 'reader_appearance_sheet.dart';
import 'reader_article_surface.dart';
import 'reader_back_guard.dart';
import 'reader_bloc.dart';
import 'reader_brightness_cubit.dart';
import 'reader_comic_surface.dart';
import 'reader_diagnostics.dart';
import 'reader_djvu_surface.dart';
import 'reader_drawer_messages.dart';
import 'reader_external_link_prompt.dart';
import 'reader_floating_chrome_layout.dart';
import 'reader_format_capabilities.dart';
import 'reader_highlight_focus_cubit.dart';
import 'reader_image_selection_cubit.dart';
import 'reader_page_thumbnail_cubit.dart';
import 'reader_page_turn.dart';
import 'reader_pdf_surface.dart';
import 'reader_position.dart';
import 'reader_screen_article_body.dart';
import 'reader_screen_chrome.dart';
import 'reader_screen_comic_body.dart';
import 'reader_screen_context_panel.dart';
import 'reader_screen_djvu_body.dart';
import 'reader_screen_drawers.dart';
import 'reader_screen_pdf_body.dart';
import 'reader_screen_text_body.dart';
import 'reader_search_cubit.dart';
import 'reader_search_event.dart';
import 'reader_search_navigation_bar.dart';
import 'reader_search_navigator.dart';
import 'reader_search_panel.dart';
import 'reader_selection_tip.dart';
import 'reader_selection_tip_cubit.dart';
import 'reader_surface.dart';
import 'reader_system_ui_overlay.dart';
import 'reader_tap_zone_hint.dart';
import 'reader_text_surface.dart';
import 'reader_toc_item.dart';
import 'reader_ui_cubit.dart';

const _kReaderLoadingIndicatorSize = AppIconSize.lg;

/// The reader scaffold behind the link sheet that external links pass.
class ReaderView extends StatelessWidget {
  const ReaderView({
    super.key,
    required this.textActions,
    required this.onRetry,
    this.initialCfi,
    this.onArticleTitlePressed,
    this.onOpenExternalLink,
  });

  final List<TextAction> textActions;
  final String? initialCfi;
  final VoidCallback onRetry;
  final void Function(String url, String title)? onArticleTitlePressed;
  final ValueChanged<String>? onOpenExternalLink;

  @override
  Widget build(BuildContext context) {
    // A link leaves the reader only after the link sheet confirms it.
    return ReaderExternalLinkPrompt(
      onOpen: onOpenExternalLink,
      builder: (context, onExternalLink) => _ReaderScaffold(
        textActions: textActions,
        initialCfi: initialCfi,
        onRetry: onRetry,
        onArticleTitlePressed: onArticleTitlePressed,
        onExternalLink: onExternalLink,
      ),
    );
  }
}

/// Full-screen reader scaffold. The page surface is created only when
/// [ReaderBloc] reaches [ReaderStatus.ready].
class _ReaderScaffold extends StatelessWidget {
  const _ReaderScaffold({
    required this.textActions,
    required this.onRetry,
    required this.onArticleTitlePressed,
    required this.onExternalLink,
    this.initialCfi,
  });

  final List<TextAction> textActions;
  final String? initialCfi;
  final VoidCallback onRetry;
  final void Function(String url, String title)? onArticleTitlePressed;
  final ValueChanged<String>? onExternalLink;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      resizeToAvoidBottomInset: false,
      body: BlocSelector<ReaderBloc, ReaderState, ReaderStatus>(
        selector: (state) => state.status,
        builder: (context, status) => _ReaderBody(
          status: status,
          textActions: textActions,
          initialCfi: initialCfi,
          onRetry: onRetry,
          onArticleTitlePressed: onArticleTitlePressed,
          onExternalLink: onExternalLink,
        ),
      ),
    );
  }
}

/// Switches between loading, failure, and ready reader content.
class _ReaderBody extends StatefulWidget {
  const _ReaderBody({
    required this.status,
    required this.textActions,
    required this.onRetry,
    this.initialCfi,
    this.onArticleTitlePressed,
    this.onExternalLink,
  });

  final ReaderStatus status;
  final List<TextAction> textActions;
  final String? initialCfi;
  final VoidCallback onRetry;
  final void Function(String url, String title)? onArticleTitlePressed;
  final ValueChanged<String>? onExternalLink;

  @override
  State<_ReaderBody> createState() => _ReaderBodyState();
}

class _ReaderBodyState extends State<_ReaderBody> {
  /// The source whose first page is on screen; the loading scrim covers
  /// the page until then.
  String? _readySourceId;

  void _handleSurfaceReady(String? sourceId) {
    if (_readySourceId == sourceId) return;
    setState(() => _readySourceId = sourceId);
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
    final surfaceReady = sourceId != null && _readySourceId == sourceId;
    final loadingVisible =
        widget.status == ReaderStatus.initial ||
        widget.status == ReaderStatus.loading ||
        (widget.status == ReaderStatus.ready && !surfaceReady);

    return Stack(
      children: [
        Positioned.fill(
          child: switch (widget.status) {
            ReaderStatus.failure => ErrorState(
              icon: AppIcons.error,
              message: context.l10n.readerFailedToLoadContent,
              retryLabel: context.l10n.commonRetry,
              onRetry: () {
                setState(() => _readySourceId = null);
                widget.onRetry();
              },
              secondaryLabel: context.l10n.readerGoBack,
              onSecondary: () => Navigator.of(context).pop(),
            ),
            ReaderStatus.ready => _ReadyContent(
              textActions: widget.textActions,
              initialCfi: widget.initialCfi,
              onArticleTitlePressed: widget.onArticleTitlePressed,
              onExternalLink: widget.onExternalLink,
              onSurfaceReady: _handleSurfaceReady,
            ),
            ReaderStatus.initial ||
            ReaderStatus.loading => const SizedBox.expand(),
          },
        ),
        IgnorePointer(
          ignoring: !loadingVisible,
          child: AnimatedOpacity(
            opacity: loadingVisible ? 1 : 0,
            duration: context.motion(AppMotion.short),
            curve: Curves.easeOutCubic,
            child: ExcludeSemantics(
              excluding: !loadingVisible,
              child: TickerMode(
                enabled: loadingVisible && !context.reduceMotion,
                child: _ReaderLoadingScrim(theme: readerTheme),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Ready reader content: the page surface, its chrome, drawers and panels,
/// and the commands between them.
class _ReadyContent extends StatefulWidget {
  const _ReadyContent({
    required this.textActions,
    required this.onSurfaceReady,
    this.initialCfi,
    this.onArticleTitlePressed,
    this.onExternalLink,
  });

  final List<TextAction> textActions;

  /// Opened instead of the saved position, once the document is ready.
  final String? initialCfi;
  final ValueChanged<String?> onSurfaceReady;
  final void Function(String url, String title)? onArticleTitlePressed;
  final ValueChanged<String>? onExternalLink;

  @override
  State<_ReadyContent> createState() => _ReadyContentState();
}

class _ReadyContentState extends State<_ReadyContent> {
  final ReaderComicSurface _comicSurface = ReaderComicSurface();
  final ReaderPdfSurface _pdfSurface = ReaderPdfSurface();
  final ReaderDjvuSurface _djvuSurface = ReaderDjvuSurface();
  final ReaderTextSurface _textSurface = ReaderTextSurface();
  final ReaderArticleSurface _articleSurface = ReaderArticleSurface();

  /// Set in build from the source type and the format.
  ReaderContentKind _pageKind = ReaderContentKind.text;

  /// Commands to the page go through the contract, never a key.
  ReaderSurface get _surface => switch (_pageKind) {
    ReaderContentKind.article => _articleSurface,
    ReaderContentKind.comic => _comicSurface,
    ReaderContentKind.pdf => _pdfSurface,
    ReaderContentKind.djvu => _djvuSurface,
    ReaderContentKind.text => _textSurface,
  };
  String? _readySourceId;
  bool _initialCfiApplied = false;
  late final ReaderSearchNavigator _searchNavigator;

  @override
  void initState() {
    super.initState();
    _searchNavigator = ReaderSearchNavigator(
      searchCubit: context.read<ReaderSearchCubit>(),
      uiCubit: context.read<ReaderUiCubit>(),
      surface: () => _surface,
      sourceType: () => context.read<ReaderBloc>().state.sourceType,
      closeSearchPanel: () => _closeSearchDrawer(
        restoreChrome: false,
        clearSearch: false,
      ),
      waitForLayout: () => WidgetsBinding.instance.endOfFrame,
    );
  }

  @override
  void dispose() {
    _searchNavigator.dispose();
    super.dispose();
  }

  /// Jumps to [_ReadyContent.initialCfi] on the first ready document.
  void _applyInitialCfi() {
    final cfi = widget.initialCfi;
    if (cfi == null || cfi.isEmpty || _initialCfiApplied) return;
    _initialCfiApplied = true;
    _surface.goToCfi(cfi);
  }

  /// The page surface starts loading its document.
  void _onSurfaceLoading() {
    if (!mounted) return;
    _searchNavigator.surfaceLoading();
    setState(() => _readySourceId = null);
    widget.onSurfaceReady(null);
  }

  /// The page surface has its first page on screen.
  void _onSurfaceReady() {
    if (!mounted) return;
    final sourceId = context.read<ReaderBloc>().state.sourceId;
    if (_readySourceId == sourceId) return;
    setState(() => _readySourceId = sourceId);
    widget.onSurfaceReady(sourceId);
    _applyInitialCfi();
  }

  void _seekFraction(double fraction) {
    _endSearch();
    context.read<ReaderUiCubit>().clearReaderSearch();
    _surface.goToFraction(fraction);
  }

  void _openTocDrawer() {
    _endSearch();
    context.read<ReaderUiCubit>().openTocDrawer();
  }

  void _closeTocDrawer({bool restoreChrome = true}) {
    _dismissReaderKeyboard();
    context.read<ReaderUiCubit>().closeTocDrawer(restoreChrome: restoreChrome);
  }

  void _openSearchDrawer() {
    _searchNavigator.openSearch();
  }

  void _toggleBookmark() {
    _surface.toggleBookmark();
  }

  Future<void> _openAppearanceSheet() async {
    _endSearch();
    final uiCubit = context.read<ReaderUiCubit>();
    final appearanceCubit = context.read<ReaderAppearanceCubit>();
    final readerState = context.read<ReaderBloc>().state;
    final capabilities = readerState.formatCapabilities;
    final showPageTurnControls = capabilities.supportsPageTurns;
    final pdfControls =
        capabilities.appearanceControls == ReaderAppearanceControls.pages;
    final showColumnControls = capabilities.supportsColumns;
    final initialPageTurnStyle =
        appearanceCubit.state.effectiveAppearance.pageTurnStyle;
    final wasChromeVisible = uiCubit.state.chromeVisible;
    // Let the chrome finish sliding out before the sheet route starts.
    final chromeHideDuration = context.motion(AppMotion.short);
    if (!uiCubit.beginAppearanceSheet()) return;
    if (wasChromeVisible) {
      await Future<void>.delayed(chromeHideDuration);
      if (!mounted) return;
    }
    await showReaderAppearanceSheet(
      context,
      showPageTurnControls: showPageTurnControls,
      showColumnControls: showColumnControls,
      pdfControls: pdfControls,
      onFullyHidden: () {
        if (!mounted) return;
        final nextPageTurnStyle =
            appearanceCubit.state.effectiveAppearance.pageTurnStyle;
        uiCubit.appearanceSheetHidden();
        if (showPageTurnControls && nextPageTurnStyle != initialPageTurnStyle) {
          uiCubit.showTapZoneHint(
            readerTapAxisForPageTurnStyle(nextPageTurnStyle),
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
    uiCubit.showTapZoneHint(readerTapAxisForPageTurnStyle(next));
  }

  void _closeSearchDrawer({
    bool restoreChrome = true,
    bool clearSearch = false,
  }) {
    _dismissReaderKeyboard();
    context.read<ReaderUiCubit>().closeSearchDrawer(
      restoreChrome:
          restoreChrome &&
          !context.read<ReaderSearchCubit>().state.isNavigating,
      clearSearch: clearSearch,
    );
  }

  void _dismissReaderKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _handleReaderPositionChanged(BookPosition position) {
    _searchNavigator.rememberLocation(
      cfi: position.cfi,
      fraction: position.fraction,
    );
    if (isReaderPageTurn(
      sourceType: context.read<ReaderBloc>().state.sourceType,
      relocationReason: position.relocationReason,
    )) {
      context.read<ReaderSelectionTipCubit>().hideForSession();
    }
    if (context.read<ReaderSearchCubit>().state.isNavigating) return;
    context.read<ReaderUiCubit>().readerPositionChanged(
      relocationReason: position.relocationReason,
    );
  }

  void _goToTocItem(ReaderTocItem item) {
    if (item.href.isEmpty) return;
    _surface.goToHref(item.href);
    _closeTocDrawer(restoreChrome: false);
  }

  /// Opens a PDF page picked in the Contents page grid.
  void _goToPage(int index) {
    _surface.goToSectionIndex(index);
    _closeTocDrawer(restoreChrome: false);
  }

  void _goToBookmark(SourceBookmark bookmark) {
    if (bookmark.cfi.isEmpty) return;
    _surface.goToBookmark(
      cfi: bookmark.cfi,
      progress: bookmark.progress,
      anchorSectionIndex: bookmark.anchorSectionIndex,
      anchorSectionPage: bookmark.anchorSectionPage,
      anchorVersion: bookmark.anchorVersion,
    );
    _closeTocDrawer(restoreChrome: false);
  }

  void _goToHighlight(Highlight highlight) {
    final imageArea = highlight.imageArea;
    if (imageArea != null) {
      _surface.goToSectionIndex(imageArea.pageIndex);
      _closeTocDrawer(restoreChrome: false);
      return;
    }
    final cfiRange = highlight.cfiRange;
    if (cfiRange == null || cfiRange.isEmpty) return;
    _surface.goToCfi(cfiRange);
    _closeTocDrawer(restoreChrome: false);
  }

  void _deleteBookmark(SourceBookmark bookmark) {
    context.read<ReaderBloc>().add(
      ReaderBookmarkDeleted(sourceId: bookmark.sourceId, id: bookmark.id),
    );
  }

  Future<void> _goToSearchResult(int index) =>
      _searchNavigator.selectResult(index);

  void _endSearch() {
    _searchNavigator.endSearch();
  }

  Future<void> _returnToReading() => _searchNavigator.returnToReading();

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

    final stream = _surface.searchBookStream(query);
    if (stream == null) {
      return Stream.value(
        ReaderSearchError(
          requestId: -1,
          message: context.l10n.readerNotReady,
        ),
      );
    }
    return stream;
  }

  @override
  Widget build(BuildContext context) {
    final searchNavigation = context
        .select<ReaderSearchCubit, ({bool active, bool canReturn})>(
          (cubit) => (
            active: cubit.state.isNavigating,
            canReturn: cubit.state.returnLocation != null,
          ),
        );
    final searchPanelVisible = context.select<ReaderUiCubit, bool>(
      (cubit) => cubit.state.searchDrawerVisible,
    );
    final navigationHeight = searchNavigation.active
        ? readerSearchNavigationHeight(
            context,
            canReturn: searchNavigation.canReturn,
          )
        : 0.0;
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
    final capabilities = context.select<ReaderBloc, ReaderFormatCapabilities>(
      (b) => b.state.formatCapabilities,
    );
    final sourceId = context.select<ReaderBloc, String?>(
      (b) => b.state.sourceId,
    );
    _pageKind = capabilities.contentKind;
    final surfaceReady = sourceId != null && _readySourceId == sourceId;
    // Reader theme drives the book *page* — its background and the reader
    // style sheet — and chrome text drawn straight on the page. Chrome
    // surfaces (capsule, drawers, popups) keep the app theme.
    final readerTheme = ReaderThemePreset.fromId(appearance.themeId).data;
    debugTraceReader(
      '_ReadyContent build '
      'sourceId=$sourceId '
      'surfaceReady=$surfaceReady '
      'format=$format '
      'theme=${appearance.themeId} '
      'layout=${appearance.layoutId}',
    );

    return ReaderBackGuard(
      onCloseSearchPanel: _closeSearchDrawer,
      onCloseTocDrawer: _closeTocDrawer,
      onDismissHighlightPopup: context.read<ReaderHighlightFocusCubit>().clear,
      onDismissImageSelection: () {
        _surface.clearImageAreaSelectionPreview();
        context.read<ReaderImageSelectionCubit>().deselect();
      },
      onEndSearch: _endSearch,
      child: _ReaderSystemUiOverlayDriver(
        readerTheme: readerTheme,
        child: MultiBlocListener(
          listeners: [
            BlocListener<ReaderSearchCubit, ReaderSearchState>(
              listenWhen: (previous, current) =>
                  previous.clearSearchToken != current.clearSearchToken,
              listener: (context, _) =>
                  context.read<ReaderUiCubit>().clearReaderSearch(),
            ),
            BlocListener<ReaderUiCubit, ReaderUiState>(
              listenWhen: (previous, current) =>
                  previous.clearSearchToken != current.clearSearchToken,
              listener: (_, _) => _surface.clearSearch(),
            ),
          ],
          child: Stack(
            children: [
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final searchOverlayBottomFraction =
                        searchPanelVisible || constraints.maxHeight <= 0
                        ? 0.0
                        : (navigationHeight / constraints.maxHeight).clamp(
                            0.0,
                            1.0,
                          );
                    return Stack(
                      children: [
                        ColoredBox(
                          color: readerTheme.backgroundColor,
                          child: switch (_pageKind) {
                            ReaderContentKind.article => ReaderArticleBody(
                              key: ValueKey('article:$sourceId'),
                              searchOverlayBottomFraction:
                                  searchOverlayBottomFraction,
                              document: context
                                  .read<ReaderBloc>()
                                  .state
                                  .document!,
                              readerTheme: readerTheme,
                              appearance: appearance,
                              surface: _articleSurface,
                              onLoading: _onSurfaceLoading,
                              onExternalLink: widget.onExternalLink,
                              onPositionChanged: _handleReaderPositionChanged,
                              onReady: _onSurfaceReady,
                            ),
                            ReaderContentKind.pdf => ReaderPdfBody(
                              key: ValueKey('pdf:$sourceId'),
                              document: context
                                  .read<ReaderBloc>()
                                  .state
                                  .document!,
                              readerTheme: readerTheme,
                              surface: _pdfSurface,
                              trimPageMargins: appearance.trimPageMargins,
                              pageColors: appearance.pageColors,
                              pageTurnStyle: appearance.pageTurnStyle,
                              pageAnimation: appearance.pageAnimation,
                              onLoading: _onSurfaceLoading,
                              onPositionChanged: _handleReaderPositionChanged,
                              onReady: _onSurfaceReady,
                            ),
                            ReaderContentKind.text => ReaderTextBody(
                              key: ValueKey('text:$sourceId'),
                              searchOverlayBottomFraction:
                                  searchOverlayBottomFraction,
                              document: context
                                  .read<ReaderBloc>()
                                  .state
                                  .document!,
                              readerTheme: readerTheme,
                              appearance: appearance,
                              surface: _textSurface,
                              onLoading: _onSurfaceLoading,
                              onExternalLink: widget.onExternalLink,
                              onPositionChanged: _handleReaderPositionChanged,
                              onReady: _onSurfaceReady,
                            ),
                            ReaderContentKind.djvu => ReaderDjvuBody(
                              key: ValueKey('djvu:$sourceId'),
                              document: context
                                  .read<ReaderBloc>()
                                  .state
                                  .document!,
                              readerTheme: readerTheme,
                              surface: _djvuSurface,
                              pageTurnStyle: appearance.pageTurnStyle,
                              pageAnimation: appearance.pageAnimation,
                              onLoading: _onSurfaceLoading,
                              onPositionChanged: _handleReaderPositionChanged,
                              onReady: _onSurfaceReady,
                            ),
                            ReaderContentKind.comic => ReaderComicBody(
                              key: ValueKey('comic:$sourceId'),
                              document: context
                                  .read<ReaderBloc>()
                                  .state
                                  .document!,
                              readerTheme: readerTheme,
                              surface: _comicSurface,
                              pageTurnStyle: appearance.pageTurnStyle,
                              pageAnimation: appearance.pageAnimation,
                              onLoading: _onSurfaceLoading,
                              onPositionChanged: _handleReaderPositionChanged,
                              onReady: _onSurfaceReady,
                            ),
                          },
                        ),
                        const _ReaderBrightnessDimmingOverlayDriver(),
                        ReaderTapZoneHintDriver(readerTheme: readerTheme),
                        const ReaderChromeDismissBarrierDriver(),
                        _ReaderTapEdgeIndicatorDriver(
                          readerTheme: readerTheme,
                          appearance: appearance,
                          visible:
                              surfaceReady && capabilities.supportsPageTurns,
                        ),
                        const ReaderPageBookmarkIndicatorDriver(),
                        ReaderFloatingChromeLayout(
                          progress: surfaceReady
                              ? ReaderArticleProgressDriver(
                                  inChromeLayout: true,
                                  readerTheme: readerTheme,
                                )
                              : null,
                          top: ReaderTopChromeDriver(
                            inChromeLayout: true,
                            readerTheme: readerTheme,
                            onArticleTitlePressed: widget.onArticleTitlePressed,
                          ),
                          brightness: const ReaderBrightnessChromeDriver(
                            inChromeLayout: true,
                          ),
                          dock: searchNavigation.active
                              ? null
                              : ReaderBottomChromeDriver(
                                  inChromeLayout: true,
                                  readerTheme: readerTheme,
                                  onTocPressed: _openTocDrawer,
                                  onFontPressed: _openAppearanceSheet,
                                  onPageTurnPressed: _togglePageTurnStyle,
                                  onBookmarkPressed: _toggleBookmark,
                                  onSearchPressed: _openSearchDrawer,
                                  onSeekFraction: _seekFraction,
                                ),
                        ),
                        const ReaderImagePageProgressOverlayDriver(),
                        ReaderSelectionTipDriver(surfaceReady: surfaceReady),
                        ReaderContextPanelDriver(
                          textActions: widget.textActions,
                          surface: _surface,
                        ),
                      ],
                    );
                  },
                ),
              ),
              if (searchNavigation.active)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ToastAvoidArea(
                    child: BlocBuilder<ReaderSearchCubit, ReaderSearchState>(
                      builder: (_, state) => ReaderSearchNavigationBar(
                        state: state,
                        onOpenSearch: _openSearchDrawer,
                        onPrevious: () => _goToSearchResult(
                          (state.activeResultIndex ?? 0) - 1,
                        ),
                        onNext: () => _goToSearchResult(
                          (state.activeResultIndex ?? 0) + 1,
                        ),
                        onEndSearch: _endSearch,
                        onReturn: _returnToReading,
                      ),
                    ),
                  ),
                ),
              _ReaderTocDrawerVisibilityDriver(
                format: format,
                loadThumbnail: (index) async => _surface.pageThumbnail(index),
                pageProgressionRtl: pageProgressionRtl,
                readerTheme: readerTheme,
                onClose: _closeTocDrawer,
                onItemSelected: _goToTocItem,
                onPageSelected: _goToPage,
                onBookmarkSelected: _goToBookmark,
                onHighlightSelected: _goToHighlight,
                onBookmarkDeleted: _deleteBookmark,
              ),
              _ReaderSearchDrawerVisibilityDriver(
                format: format,
                pageProgressionRtl: pageProgressionRtl,
                onClose: _closeSearchDrawer,
                onSearch: _searchBook,
                onResultSelected: _goToSearchResult,
              ),
            ],
          ),
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
          duration: context.motion(AppMotion.quick),
          curve: Curves.easeOutCubic,
          builder: (_, value, _) {
            // Screen dimming is a pure luminance reduction: the scrim role,
            // not a themed surface color.
            return ColoredBox(
              color: context.colors.scrim.withValues(alpha: value),
            );
          },
        ),
      ),
    );
  }
}

/// Derives the platform status/navigation bar style from the reader theme.
class _ReaderSystemUiOverlayDriver extends StatelessWidget {
  const _ReaderSystemUiOverlayDriver({
    required this.readerTheme,
    required this.child,
  });

  final ReaderThemeData readerTheme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: readerSystemUiOverlayStyle(
        readerTheme: readerTheme,
        appNavigationBarColor: context.appTheme.backgroundColor,
      ),
      child: child,
    );
  }
}

/// Subscribes only to TOC drawer visibility and forwards stable callbacks to
/// the drawer widget.
class _ReaderTocDrawerVisibilityDriver extends StatelessWidget {
  const _ReaderTocDrawerVisibilityDriver({
    required this.loadThumbnail,
    required this.format,
    required this.pageProgressionRtl,
    required this.readerTheme,
    required this.onClose,
    required this.onItemSelected,
    required this.onPageSelected,
    required this.onBookmarkSelected,
    required this.onHighlightSelected,
    required this.onBookmarkDeleted,
  });

  final PageThumbnailLoader loadThumbnail;
  final BookFormat? format;
  final bool pageProgressionRtl;
  final ReaderThemeData readerTheme;
  final void Function({bool restoreChrome}) onClose;
  final ValueChanged<ReaderTocItem> onItemSelected;
  final ValueChanged<int> onPageSelected;
  final ValueChanged<SourceBookmark> onBookmarkSelected;
  final ValueChanged<Highlight> onHighlightSelected;
  final ValueChanged<SourceBookmark> onBookmarkDeleted;

  @override
  Widget build(BuildContext context) {
    final visible = context.select<ReaderUiCubit, bool>(
      (c) => c.state.overlay == ReaderOverlay.toc,
    );

    return BlocListener<ReaderUiCubit, ReaderUiState>(
      listenWhen: (previous, current) =>
          previous.overlay == ReaderOverlay.toc &&
          current.overlay != ReaderOverlay.toc,
      listener: (context, _) => context.read<ReaderBloc>()
        ..add(const ReaderBookmarkUndoDismissed())
        ..add(const ReaderHighlightUndoDismissed()),
      child: ReaderTocDrawerDriver(
        loadThumbnail: loadThumbnail,
        visible: visible,
        format: format,
        pageProgressionRtl: pageProgressionRtl,
        readerTheme: readerTheme,
        onClose: onClose,
        onItemSelected: onItemSelected,
        onPageSelected: onPageSelected,
        onBookmarkSelected: onBookmarkSelected,
        onHighlightSelected: onHighlightSelected,
        onBookmarkDeleted: onBookmarkDeleted,
      ),
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
    required this.onResultSelected,
  });

  final BookFormat? format;
  final bool pageProgressionRtl;
  final void Function({bool restoreChrome, bool clearSearch}) onClose;
  final Stream<ReaderSearchEvent> Function(String query) onSearch;
  final ValueChanged<int> onResultSelected;

  @override
  Widget build(BuildContext context) {
    final visible = context.select<ReaderUiCubit, bool>(
      (c) => c.state.overlay == ReaderOverlay.search,
    );

    return Positioned.fill(
      child: ReaderSearchPanel(
        visible: visible,
        format: format,
        pageProgressionRtl: pageProgressionRtl,
        onClose: onClose,
        onSearch: onSearch,
        onResultSelected: onResultSelected,
      ),
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
    debugTraceReader(
      '_ReaderTapEdgeIndicatorDriver build '
      'visible=$visible '
      'rtl=$pageProgressionRtl '
      'canGoPrevious=$canGoPrevious '
      'canGoNext=$canGoNext '
      'pageTurn=${appearance.pageTurnStyle.id}',
    );

    return ReaderTapEdgeIndicator(
      readerTheme: readerTheme,
      axis: readerTapAxisForPageTurnStyle(appearance.pageTurnStyle),
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

class _ReaderLoadingIndicator extends StatelessWidget {
  const _ReaderLoadingIndicator({required this.theme});

  final ReaderThemeData theme;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: _kReaderLoadingIndicatorSize,
      child: AppProgressIndicator(
        key: const ValueKey('readerLoadingProgress'),
        strokeWidth: 2,
        color: theme.primaryTextColor.withValues(alpha: 0.82),
        semanticsLabel: context.l10n.readerLoadingContent,
      ),
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
        child: _ReaderLoadingIndicator(theme: theme),
      ),
    );
  }
}
