import 'dart:async';

import 'package:article_repository/article_repository.dart';
import 'package:book_repository/book_repository.dart';
import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:highlight_repository/highlight_repository.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:reader_webview/reader_webview.dart';
import 'package:screen_control_service/screen_control_service.dart';
import 'package:shared/shared.dart';

import 'book_custom_css.dart';
import 'reader_appearance_cubit.dart';
import 'reader_appearance_sheet.dart';
import 'reader_bookmark_filter.dart';
import 'reader_bloc.dart';
import 'reader_brightness_cubit.dart';
import 'reader_chrome_actions.dart';
import 'reader_color_utils.dart';
import 'reader_device_font_scale.dart';
import 'reader_loading_indicator_style.dart';
import 'reader_progress_label.dart';
import 'reader_review_reminder_cubit.dart';
import 'reader_search_cubit.dart';
import 'reader_selection_cubit.dart';
import 'reader_system_ui_overlay.dart';
import 'reader_tap_action.dart';
import 'reader_ui_cubit.dart';

/// Approximate height of the context panel, used to offset the review banner.
const _kContextPanelHeight = 80.0;

/// Duration and curve for the reader chrome slide animation.
const _kChromeAnimDuration = Duration(milliseconds: 200);
const _kChromeAnimCurve = Curves.easeOutCubic;
const _kChromeHideAnimCurve = Curves.easeInCubic;
const _kReaderTopChromeHeight = 64.0;
const _kReaderPageBookmarkIndicatorLift = 28.0;
const _kReaderPageBookmarkIndicatorSize = AppIconSize.md;
const _kReaderBrightnessStep = 0.05;
const _kReaderBrightnessEpsilon = 0.0001;
const _kReaderBrightnessChromeWidth = 56.0;
const _kReaderBrightnessChromeHeight = 190.0;
const _kReaderBrightnessChromeDragHeight =
    _kReaderBrightnessChromeHeight - AppSpacing.sm * 2;

final _readerDrawerCloseButtonStyle = IconButton.styleFrom(
  backgroundColor: Colors.transparent,
  disabledBackgroundColor: Colors.transparent,
  hoverColor: Colors.transparent,
  focusColor: Colors.transparent,
  highlightColor: Colors.transparent,
);

double _readerDrawerListBottomPadding(BuildContext context) {
  return MediaQuery.viewInsetsOf(context).bottom +
      MediaQuery.paddingOf(context).bottom +
      AppSpacing.lg;
}

/// Carries the optional mini-review callback down the reader widget tree.
class _ReaderCallbacksScope extends InheritedWidget {
  const _ReaderCallbacksScope({
    required this.onStartMiniReview,
    required super.child,
  });

  final void Function(BuildContext context, String sourceId)? onStartMiniReview;

  static _ReaderCallbacksScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ReaderCallbacksScope>();

  @override
  bool updateShouldNotify(_ReaderCallbacksScope old) =>
      onStartMiniReview != old.onStartMiniReview;
}

/// Full-screen reader for a book (route `/reader/:sourceId`).
///
/// Composition only: wires [ReaderBloc] (source + highlights + position
/// persistence), [ReaderUiCubit] (chrome/drawer/search-highlight state),
/// [ReaderSearchCubit] (book-search state), and [ReaderSelectionCubit]
/// (text selection) around an internal [_ReaderView]. [textActions] follow
/// the plugin contract from `package:shared` — features like Highlight /
/// Flashcard / Translate are wired in the composition root.
class ReaderScreen extends StatelessWidget {
  const ReaderScreen({
    required this.sourceId,
    required this.serverPort,
    required this.bookRepository,
    required this.highlightRepository,
    required this.preferencesService,
    required this.screenControlService,
    required this.textActions,
    this.initialSearchHistory = const [],
    this.articleRepository,
    this.initialSource,
    this.initialSourceType = SourceType.book,
    this.onSearchHistoryChanged,
    this.onSourceOpened,
    this.onCheckDueItems,
    this.onStartMiniReview,
    super.key,
  });

  final String sourceId;
  final int serverPort;
  final BookRepository bookRepository;
  final ArticleRepository? articleRepository;
  final HighlightRepository highlightRepository;
  final PreferencesService preferencesService;
  final ScreenControlService screenControlService;
  final List<TextAction> textActions;
  final List<String> initialSearchHistory;
  final Book? initialSource;
  final SourceType initialSourceType;
  final ValueChanged<List<String>>? onSearchHistoryChanged;
  final VoidCallback? onSourceOpened;
  final Future<int> Function(String sourceId)? onCheckDueItems;
  final void Function(BuildContext context, String sourceId)? onStartMiniReview;

  @override
  Widget build(BuildContext context) {
    debugLogScreenBuild('ReaderScreen(sourceId: $sourceId)');

    return _ReaderCallbacksScope(
      onStartMiniReview: onStartMiniReview,
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => ReaderBloc(
              bookRepository: bookRepository,
              articleRepository: articleRepository,
              highlightRepository: highlightRepository,
              initialSource: initialSource?.id == sourceId
                  ? initialSource
                  : null,
              initialSourceType: initialSourceType,
            )..add(ReaderSourceLoadRequested(sourceId: sourceId)),
          ),
          BlocProvider(create: (_) => ReaderUiCubit()),
          BlocProvider(
            create: (_) => ReaderSearchCubit(
              initialRecentQueries: initialSearchHistory,
              onRecentQueriesChanged: onSearchHistoryChanged,
            ),
          ),
          BlocProvider(create: (_) => ReaderSelectionCubit()),
          BlocProvider(
            create: (_) => ReaderAppearanceCubit(
              preferencesService: preferencesService,
              sourceId: sourceId,
            ),
          ),
          BlocProvider(
            create: (_) => ReaderReviewReminderCubit(
              sourceId: sourceId,
              onCheckDueItems: onCheckDueItems,
            ),
          ),
          BlocProvider(
            create: (_) => ReaderBrightnessCubit(
              preferencesService: preferencesService,
              screenControlService: screenControlService,
              sourceId: sourceId,
            ),
          ),
        ],
        child: Builder(
          builder: (context) => _ReaderSourceOpenedNotifier(
            onSourceOpened: onSourceOpened,
            child: ReaderBrightnessLifecycleScope(
              cubit: context.read<ReaderBrightnessCubit>(),
              child: ReaderKeepAwakeDriver(
                screenControlService: screenControlService,
                child: _ReaderView(
                  serverPort: serverPort,
                  textActions: textActions,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReaderSourceOpenedNotifier extends StatefulWidget {
  const _ReaderSourceOpenedNotifier({
    required this.onSourceOpened,
    required this.child,
  });

  final VoidCallback? onSourceOpened;
  final Widget child;

  @override
  State<_ReaderSourceOpenedNotifier> createState() =>
      _ReaderSourceOpenedNotifierState();
}

class _ReaderSourceOpenedNotifierState
    extends State<_ReaderSourceOpenedNotifier> {
  bool _notified = false;

  @override
  Widget build(BuildContext context) {
    return BlocListener<ReaderBloc, ReaderState>(
      listenWhen: (previous, current) {
        if (_notified || current.status != ReaderStatus.ready) {
          return false;
        }
        final previousOpenedAt = previous.book?.lastOpenedAt;
        final currentOpenedAt = current.book?.lastOpenedAt;
        return currentOpenedAt != null && currentOpenedAt != previousOpenedAt;
      },
      listener: (_, _) {
        if (_notified) return;
        _notified = true;
        widget.onSourceOpened?.call();
      },
      child: widget.child,
    );
  }
}

class ReaderKeepAwakeDriver extends StatelessWidget {
  const ReaderKeepAwakeDriver({
    required this.screenControlService,
    required this.child,
    super.key,
  });

  final ScreenControlService screenControlService;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final readerReady = context.select<ReaderBloc, bool>(
      (bloc) => bloc.state.status == ReaderStatus.ready,
    );

    return BlocSelector<ReaderUiCubit, ReaderUiState, bool>(
      selector: (state) => state.contentOnlyVisible,
      builder: (context, contentOnlyVisible) {
        return ReaderKeepAwakeScope(
          active: readerReady && contentOnlyVisible,
          screenControlService: screenControlService,
          child: child,
        );
      },
    );
  }
}

/// Keeps the device awake only while the reader shows bare reading content.
///
/// Chrome panels, drawers, and bottom sheets release keep-awake because the user
/// is interacting with controls rather than passively reading.
class ReaderKeepAwakeScope extends StatefulWidget {
  const ReaderKeepAwakeScope({
    required this.active,
    required this.screenControlService,
    required this.child,
    super.key,
  });

  final bool active;
  final ScreenControlService screenControlService;
  final Widget child;

  @override
  State<ReaderKeepAwakeScope> createState() => _ReaderKeepAwakeScopeState();
}

class _ReaderKeepAwakeScopeState extends State<ReaderKeepAwakeScope>
    with WidgetsBindingObserver {
  bool _keepAwakeRequested = false;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_sync());
  }

  @override
  void didUpdateWidget(ReaderKeepAwakeScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != oldWidget.active ||
        widget.screenControlService != oldWidget.screenControlService) {
      unawaited(_sync());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _foreground = true;
        unawaited(_sync());
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _foreground = false;
        unawaited(_sync());
        break;
    }
  }

  Future<void> _sync() {
    if (widget.active && _foreground) {
      return _keepAwake();
    }
    return _allowSleep();
  }

  Future<void> _keepAwake() async {
    if (_keepAwakeRequested) {
      return;
    }
    _keepAwakeRequested = true;
    await widget.screenControlService.keepAwake();
  }

  Future<void> _allowSleep() async {
    if (!_keepAwakeRequested) {
      return;
    }
    _keepAwakeRequested = false;
    await widget.screenControlService.allowSleep();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_allowSleep());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class ReaderBrightnessLifecycleScope extends StatefulWidget {
  const ReaderBrightnessLifecycleScope({
    required this.cubit,
    required this.child,
    super.key,
  });

  final ReaderBrightnessCubit cubit;
  final Widget child;

  @override
  State<ReaderBrightnessLifecycleScope> createState() =>
      _ReaderBrightnessLifecycleScopeState();
}

class _ReaderBrightnessLifecycleScopeState
    extends State<ReaderBrightnessLifecycleScope>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.cubit.activate();
  }

  @override
  void didUpdateWidget(ReaderBrightnessLifecycleScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.cubit == oldWidget.cubit) return;
    unawaited(oldWidget.cubit.deactivate());
    widget.cubit.activate();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        widget.cubit.activate();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        unawaited(widget.cubit.deactivate());
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(widget.cubit.deactivate());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _ReaderView extends StatelessWidget {
  const _ReaderView({
    required this.serverPort,
    required this.textActions,
  });

  final int serverPort;
  final List<TextAction> textActions;

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
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReaderBody extends StatelessWidget {
  const _ReaderBody({
    required this.status,
    required this.serverPort,
    required this.textActions,
  });

  final ReaderStatus status;
  final int serverPort;
  final List<TextAction> textActions;

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
      ),
    };
  }
}

/// Plain icon button used in the reader action chrome — no background,
/// no theme-injected `secondary` fill. Greys out automatically when
/// `onPressed` is null so unfinished slots read as disabled.
class _ReaderChromeIconButton extends StatelessWidget {
  const _ReaderChromeIconButton({
    required this.icon,
    required this.tooltip,
    required this.foregroundColor,
    this.iconSize = AppIconSize.md,
    this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final Color foregroundColor;
  final double iconSize;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return SizedBox.square(
      dimension: AppSizes.buttonHeight,
      child: IconButton(
        icon: Icon(icon, size: iconSize),
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: disabled
              ? foregroundColor.withValues(alpha: 0.35)
              : foregroundColor,
          minimumSize: const Size.square(AppSizes.iconButtonSize),
          padding: const EdgeInsets.all(AppSpacing.sm),
        ),
      ),
    );
  }
}

class _ReaderBookmarkIconButton extends StatelessWidget {
  const _ReaderBookmarkIconButton({
    required this.active,
    required this.tooltip,
    required this.foregroundColor,
    required this.activeColor,
    this.onPressed,
  });

  final bool active;
  final String tooltip;
  final Color foregroundColor;
  final Color activeColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    final color = active ? activeColor : foregroundColor;
    return IconButton(
      icon: _ReaderBookmarkGlyph(
        filled: active,
        color: disabled ? color.withValues(alpha: 0.35) : color,
        size: AppIconSize.md,
      ),
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: disabled ? color.withValues(alpha: 0.35) : color,
      ),
    );
  }
}

class _ReaderBookmarkGlyph extends StatelessWidget {
  const _ReaderBookmarkGlyph({
    required this.filled,
    required this.color,
    required this.size,
  });

  final bool filled;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _ReaderBookmarkGlyphPainter(
          color: color,
          filled: filled,
        ),
      ),
    );
  }
}

class _ReaderBookmarkGlyphPainter extends CustomPainter {
  const _ReaderBookmarkGlyphPainter({
    required this.color,
    required this.filled,
  });

  final Color color;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 24;
    final path = Path()
      ..moveTo(5, 21)
      ..lineTo(12, 17)
      ..lineTo(19, 21)
      ..lineTo(19, 5)
      ..quadraticBezierTo(19, 3, 17, 3)
      ..lineTo(7, 3)
      ..quadraticBezierTo(5, 3, 5, 5)
      ..close();

    canvas.save();
    canvas.scale(scale, scale);

    if (filled) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.fill
          ..color = color,
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ReaderBookmarkGlyphPainter oldDelegate) {
    return color != oldDelegate.color || filled != oldDelegate.filled;
  }
}

class _ReadyContent extends StatelessWidget {
  const _ReadyContent({
    required this.serverPort,
    required this.textActions,
  });

  final int serverPort;
  final List<TextAction> textActions;

  @override
  Widget build(BuildContext context) {
    return _ReadyContentBody(
      serverPort: serverPort,
      textActions: textActions,
    );
  }
}

class _ReadyContentBody extends StatefulWidget {
  const _ReadyContentBody({
    required this.serverPort,
    required this.textActions,
  });

  final int serverPort;
  final List<TextAction> textActions;

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
        context.read<ReaderUiCubit>().appearanceSheetHidden();
      },
    );
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

  void _goToSearchResult(ReaderSearchResult result) {
    if (result.cfi.isEmpty) return;
    context.read<ReaderSearchCubit>().resultSelected();
    context.read<ReaderUiCubit>().searchResultHighlightActivated();
    _webViewKey.currentState?.goToCfi(result.cfi);
    _closeSearchDrawer(restoreChrome: false, clearSearch: false);
  }

  Stream<ReaderSearchEvent> _searchBook(String query) {
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
    final uiState = context.select<ReaderUiCubit, ReaderUiState>(
      (c) => c.state,
    );
    // Reader theme drives the book *page* — WebView background and
    // foliate-js customCSS. Chrome (passed-through Stack siblings)
    // pulls colours from the app theme themselves; they don't take
    // a `readerTheme` prop any more.
    final readerTheme = ReaderThemePreset.fromId(appearance.themeId).data;
    final systemUiStyle = readerSystemUiOverlayStyle(
      readerTheme: readerTheme,
      chromeVisible: uiState.chromeVisible,
      chromeSurfaceColor: context.colors.surface,
      appNavigationBarColor: Theme.of(context).scaffoldBackgroundColor,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemUiStyle,
      child: BlocListener<ReaderUiCubit, ReaderUiState>(
        listenWhen: (previous, current) =>
            previous.clearSearchToken != current.clearSearchToken,
        listener: (_, _) => _webViewKey.currentState?.clearSearch(),
        child: Stack(
          children: [
            // WebView body — subscribes to `state.highlights` via
            // `context.select` so a TextAction (Highlight, Flashcard, ...)
            // that adds/removes one fans through to the WebView via
            // didUpdateWidget without forcing a reader reopen.
            ColoredBox(
              color: readerTheme.backgroundColor,
              child: _ReaderWebViewBody(
                serverPort: widget.serverPort,
                readerTheme: readerTheme,
                webViewKey: _webViewKey,
                onPositionChanged: _handleReaderPositionChanged,
              ),
            ),
            const _ReaderChromeDismissBarrierDriver(),
            const _ReaderTopChromeDriver(),
            const _ReaderPageBookmarkIndicatorDriver(),
            const ReaderBrightnessChromeDriver(),
            _ReaderBottomChromeDriver(
              onTocPressed: _openTocDrawer,
              onFontPressed: _openAppearanceSheet,
              onBookmarkPressed: _toggleBookmark,
              onSearchPressed: _openSearchDrawer,
              onSeekFraction: _seekFraction,
            ),
            const _ComicProgressOverlayDriver(),
            _ContextPanelDriver(textActions: widget.textActions),
            const _ReviewReminderDriver(),
            _ReaderTocDrawerDriver(
              visible: uiState.tocDrawerVisible,
              onClose: _closeTocDrawer,
              onItemSelected: _goToTocItem,
              onBookmarkSelected: _goToBookmark,
            ),
            _ReaderSearchDrawer(
              visible: uiState.searchDrawerVisible,
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

/// Blocks page input while reader chrome is visible.
///
/// WebView gestures are native enough that tap-zone logic alone is not
/// sufficient: a swipe can still reach foliate-js before Flutter decides it is
/// not a tap. This barrier sits above the page but below the chrome panels; any
/// pointer on the page hides chrome and is not forwarded to the WebView.
class _ReaderChromeDismissBarrierDriver extends StatelessWidget {
  const _ReaderChromeDismissBarrierDriver();

  @override
  Widget build(BuildContext context) {
    final uiState = context.select<ReaderUiCubit, ReaderUiState>(
      (c) => c.state,
    );
    final hasSelection = context.select<ReaderSelectionCubit, bool>(
      (c) => c.state.hasSelection,
    );
    final shouldBlockPage = shouldBlockReaderPageInput(
      chromeVisible: uiState.chromeVisible,
      overlayVisible: uiState.overlay != ReaderOverlay.none,
      hasSelection: hasSelection,
    );

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !shouldBlockPage,
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) => context.read<ReaderUiCubit>().hideChrome(),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// Places brightness next to the page while reader chrome is visible.
///
/// This stays outside the Aa sheet so the user can see brightness changes
/// against the current page instead of a separate settings surface.
class ReaderBrightnessChromeDriver extends StatelessWidget {
  const ReaderBrightnessChromeDriver({super.key});

  @override
  Widget build(BuildContext context) {
    final uiState = context.select<ReaderUiCubit, ReaderUiState>(
      (c) => c.state,
    );
    final hasSelection = context.select<ReaderSelectionCubit, bool>(
      (c) => c.state.hasSelection,
    );
    final brightnessState = context
        .select<ReaderBrightnessCubit, ReaderBrightnessState>(
          (c) => c.state,
        );
    final cubit = context.read<ReaderBrightnessCubit>();
    final visible =
        uiState.chromeVisible &&
        uiState.overlay == ReaderOverlay.none &&
        !hasSelection;
    double brightnessAfterDelta(double delta) {
      return (brightnessState.sliderValue + delta)
          .clamp(
            ReaderBrightnessCubit.minBrightness,
            ReaderBrightnessCubit.maxBrightness,
          )
          .toDouble();
    }

    void changeBrightnessBy(double delta) {
      final nextValue = brightnessAfterDelta(delta);
      cubit.previewBrightness(nextValue);
      cubit.commitBrightness(nextValue);
    }

    return _ReaderBrightnessChrome(
      visible: visible,
      value: brightnessState.sliderValue,
      label: brightnessState.usesSystemBrightness
          ? 'System'
          : '${brightnessState.percent}%',
      usesSystemBrightness: brightnessState.usesSystemBrightness,
      canIncrease:
          brightnessState.sliderValue <
          ReaderBrightnessCubit.maxBrightness - _kReaderBrightnessEpsilon,
      canDecrease:
          brightnessState.sliderValue >
          ReaderBrightnessCubit.minBrightness + _kReaderBrightnessEpsilon,
      onIncrease: () => changeBrightnessBy(_kReaderBrightnessStep),
      onDecrease: () => changeBrightnessBy(-_kReaderBrightnessStep),
      onDragPreview: cubit.previewBrightness,
      onDragEnd: cubit.commitBrightness,
      onUseSystem: () => unawaited(cubit.useSystemBrightness()),
    );
  }
}

class _ReaderBrightnessChrome extends StatefulWidget {
  const _ReaderBrightnessChrome({
    required this.visible,
    required this.value,
    required this.label,
    required this.usesSystemBrightness,
    required this.canIncrease,
    required this.canDecrease,
    required this.onIncrease,
    required this.onDecrease,
    required this.onDragPreview,
    required this.onDragEnd,
    required this.onUseSystem,
  });

  final bool visible;
  final double value;
  final String label;
  final bool usesSystemBrightness;
  final bool canIncrease;
  final bool canDecrease;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final ValueChanged<double> onDragPreview;
  final ValueChanged<double> onDragEnd;
  final VoidCallback onUseSystem;

  @override
  State<_ReaderBrightnessChrome> createState() =>
      _ReaderBrightnessChromeState();
}

class _ReaderBrightnessChromeState extends State<_ReaderBrightnessChrome> {
  double? _dragPreviewValue;

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    final dy = details.primaryDelta;
    if (dy == null || dy == 0) return;
    final brightnessRange =
        ReaderBrightnessCubit.maxBrightness -
        ReaderBrightnessCubit.minBrightness;
    final delta = -dy / _kReaderBrightnessChromeDragHeight * brightnessRange;
    final nextValue = ((_dragPreviewValue ?? widget.value) + delta)
        .clamp(
          ReaderBrightnessCubit.minBrightness,
          ReaderBrightnessCubit.maxBrightness,
        )
        .toDouble();
    if (nextValue == _dragPreviewValue) return;
    _dragPreviewValue = nextValue;
    widget.onDragPreview(nextValue);
  }

  void _flushDrag() {
    final value = _dragPreviewValue;
    if (value == null) return;
    _dragPreviewValue = null;
    widget.onDragEnd(value);
  }

  @override
  Widget build(BuildContext context) {
    final curve = widget.visible ? _kChromeAnimCurve : _kChromeHideAnimCurve;
    final cs = context.colors;
    final borderColor = cs.outlineVariant.withValues(alpha: 0.72);
    final foreground = cs.onSurface.withValues(alpha: 0.74);

    return Positioned(
      top: 0,
      right: AppSpacing.md,
      bottom: 0,
      child: SafeArea(
        left: false,
        top: false,
        bottom: false,
        child: Center(
          child: IgnorePointer(
            key: const ValueKey('readerBrightnessChromeIgnorePointer'),
            ignoring: !widget.visible,
            child: AnimatedOpacity(
              opacity: widget.visible ? 1 : 0,
              duration: _kChromeAnimDuration,
              curve: curve,
              child: AnimatedSlide(
                offset: widget.visible ? Offset.zero : const Offset(0.18, 0),
                duration: _kChromeAnimDuration,
                curve: curve,
                child: GestureDetector(
                  key: const ValueKey('readerBrightnessChromeDragArea'),
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragUpdate: _handleVerticalDragUpdate,
                  onVerticalDragEnd: (_) => _flushDrag(),
                  onVerticalDragCancel: _flushDrag,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      border: Border.all(
                        color: borderColor,
                        width: 1 / MediaQuery.devicePixelRatioOf(context),
                      ),
                      boxShadow: AppShadows.panelUp,
                    ),
                    child: SizedBox(
                      width: _kReaderBrightnessChromeWidth,
                      height: _kReaderBrightnessChromeHeight,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                          vertical: AppSpacing.sm,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _ReaderBrightnessStepButton(
                              tooltip: 'Increase brightness',
                              icon: AppIcons.lightMode,
                              enabled: widget.canIncrease,
                              foreground: foreground,
                              onPressed: widget.onIncrease,
                            ),
                            _ReaderBrightnessValueButton(
                              widget.label,
                              usesSystemBrightness: widget.usesSystemBrightness,
                              onPressed: widget.usesSystemBrightness
                                  ? null
                                  : widget.onUseSystem,
                            ),
                            _ReaderBrightnessStepButton(
                              tooltip: 'Decrease brightness',
                              icon: AppIcons.brightnessLow,
                              enabled: widget.canDecrease,
                              foreground: foreground,
                              onPressed: widget.onDecrease,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReaderBrightnessStepButton extends StatelessWidget {
  const _ReaderBrightnessStepButton({
    required this.tooltip,
    required this.icon,
    required this.enabled,
    required this.foreground,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final bool enabled;
  final Color foreground;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final iconColor = foreground.withValues(alpha: enabled ? 1 : 0.32);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled ? onPressed : null,
          child: SizedBox.square(
            dimension: 36,
            child: Icon(icon, size: AppIconSize.sm, color: iconColor),
          ),
        ),
      ),
    );
  }
}

class _ReaderBrightnessValueButton extends StatelessWidget {
  const _ReaderBrightnessValueButton(
    this.label, {
    required this.usesSystemBrightness,
    required this.onPressed,
  });

  final String label;
  final bool usesSystemBrightness;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final text = context.text;
    final active = !usesSystemBrightness;

    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: usesSystemBrightness
          ? 'Using system brightness'
          : 'Use system brightness',
      child: Material(
        color: active
            ? cs.primary.withValues(alpha: 0.12)
            : cs.secondary.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onPressed,
          child: SizedBox(
            width: 44,
            height: 34,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: usesSystemBrightness
                    ? Icon(
                        AppIcons.deviceMode,
                        size: AppIconSize.sm,
                        color: cs.onSurface,
                      )
                    : Text(
                        label,
                        maxLines: 1,
                        style: text.labelSmall.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReaderPageBookmarkIndicatorDriver extends StatelessWidget {
  const _ReaderPageBookmarkIndicatorDriver();

  @override
  Widget build(BuildContext context) {
    final uiState = context.select<ReaderUiCubit, ReaderUiState>(
      (c) => c.state,
    );
    final hasSelection = context.select<ReaderSelectionCubit, bool>(
      (c) => c.state.hasSelection,
    );
    final bookmarked = context.select<ReaderBloc, bool>(
      (b) => b.state.currentPageBookmarked,
    );
    final layoutId = context.select<ReaderAppearanceCubit, String>(
      (c) => c.state.effectiveAppearance.layoutId,
    );
    final visible = bookmarked && uiState.contentOnlyVisible && !hasSelection;
    final topOffset =
        BookLayoutPreset.fromId(layoutId).data.topMargin -
        _kReaderPageBookmarkIndicatorLift;

    return _ReaderPageBookmarkIndicator(
      visible: visible,
      color: context.colors.primary,
      topOffset: topOffset,
    );
  }
}

class _ReaderPageBookmarkIndicator extends StatelessWidget {
  const _ReaderPageBookmarkIndicator({
    required this.visible,
    required this.color,
    required this.topOffset,
  });

  final bool visible;
  final Color color;
  final double topOffset;

  @override
  Widget build(BuildContext context) {
    final curve = visible ? _kChromeAnimCurve : _kChromeHideAnimCurve;

    return Positioned(
      top: topOffset,
      right: AppSpacing.md,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: _kChromeAnimDuration,
          curve: curve,
          child: Semantics(
            label: 'Page bookmarked',
            child: _ReaderBookmarkGlyph(
              filled: true,
              color: color,
              size: _kReaderPageBookmarkIndicatorSize,
            ),
          ),
        ),
      ),
    );
  }
}

class _ReaderTopChromeDriver extends StatelessWidget {
  const _ReaderTopChromeDriver();

  @override
  Widget build(BuildContext context) {
    final chromeVisible = context.select<ReaderUiCubit, bool>(
      (c) => c.state.chromeVisible,
    );
    final hasSelection = context.select<ReaderSelectionCubit, bool>(
      (c) => c.state.hasSelection,
    );
    final title = context.select<ReaderBloc, String>(
      (b) =>
          b.state.title.isNotEmpty ? b.state.title : b.state.book?.title ?? '',
    );
    final colors = context.colors;

    return _ReaderTopChrome(
      visible: chromeVisible && !hasSelection,
      title: title,
      panelColor: colors.surface,
      titleColor: colors.onSurface,
      dividerColor: colors.outlineVariant,
    );
  }
}

class _ReaderTopChrome extends StatelessWidget {
  const _ReaderTopChrome({
    required this.visible,
    required this.title,
    required this.panelColor,
    required this.titleColor,
    required this.dividerColor,
  });

  final bool visible;
  final String title;
  final Color panelColor;
  final Color titleColor;
  final Color dividerColor;

  @override
  Widget build(BuildContext context) {
    final chromeAnimCurve = visible ? _kChromeAnimCurve : _kChromeHideAnimCurve;

    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedSlide(
          offset: visible ? Offset.zero : const Offset(0, -1),
          duration: _kChromeAnimDuration,
          curve: chromeAnimCurve,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: _kChromeAnimDuration,
            curve: chromeAnimCurve,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: panelColor,
                boxShadow: AppShadows.panelDown,
                border: Border(
                  bottom: BorderSide(
                    color: dividerColor,
                    width: 1 / MediaQuery.devicePixelRatioOf(context),
                  ),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: SizedBox(
                  height: _kReaderTopChromeHeight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    child: Center(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: context.text.bodyMedium.copyWith(
                          fontFamily: ReaderFontPreset.serif.fontFamily,
                          color: titleColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Combines chrome visibility from [ReaderUiCubit], selection state from
/// [ReaderSelectionCubit], and reading progress from [ReaderBloc].
class _ReaderBottomChromeDriver extends StatelessWidget {
  const _ReaderBottomChromeDriver({
    required this.onTocPressed,
    required this.onFontPressed,
    required this.onBookmarkPressed,
    required this.onSearchPressed,
    required this.onSeekFraction,
  });

  final VoidCallback onTocPressed;
  final VoidCallback onFontPressed;
  final VoidCallback onBookmarkPressed;
  final VoidCallback onSearchPressed;

  /// Forwarded to the slider's drag-end handler. Skips the bloc entirely —
  /// the WebView's `goToFraction` triggers `onRelocated` once the new page
  /// lands and the bloc updates from there.
  final ValueChanged<double> onSeekFraction;

  @override
  Widget build(BuildContext context) {
    final chromeVisible = context.select<ReaderUiCubit, bool>(
      (c) => c.state.chromeVisible,
    );
    final hasSelection = context.select<ReaderSelectionCubit, bool>(
      (c) => c.state.hasSelection,
    );
    final progress = context.select<ReaderBloc, double>(
      (b) => b.state.book?.readingProgress ?? 0,
    );
    final chapterTitle = context.select<ReaderBloc, String?>(
      (b) => b.state.chapterTitle,
    );
    final chapterCurrentPage = context.select<ReaderBloc, int?>(
      (b) => b.state.chapterCurrentPage,
    );
    final chapterTotalPages = context.select<ReaderBloc, int?>(
      (b) => b.state.chapterTotalPages,
    );
    final currentPageBookmarked = context.select<ReaderBloc, bool>(
      (b) => b.state.currentPageBookmarked,
    );
    final format = context.select<ReaderBloc, BookFormat?>(
      (b) => b.state.book?.format,
    );
    final sourceType = context.select<ReaderBloc, SourceType>(
      (b) => b.state.sourceType,
    );
    final actions = readerChromeActionsForFormat(format);
    final colors = context.colors;

    return _ReaderBottomChrome(
      visible: chromeVisible && !hasSelection,
      progress: progress,
      chapterTitle: chapterTitle,
      chapterCurrentPage: chapterCurrentPage,
      chapterTotalPages: chapterTotalPages,
      sourceType: sourceType,
      format: format,
      panelColor: colors.surface,
      textColor: colors.onSurfaceVariant,
      accentColor: colors.primary,
      dividerColor: colors.outlineVariant,
      foregroundColor: colors.onSurface,
      bookmarkActive: currentPageBookmarked,
      showTocAction: actions.contains(ReaderChromeAction.contents),
      showFontAction: actions.contains(ReaderChromeAction.textAppearance),
      showBookmarkAction: actions.contains(ReaderChromeAction.bookmark),
      showSearchAction: actions.contains(ReaderChromeAction.textSearch),
      onBack: () => Navigator.of(context).maybePop(),
      onTocPressed: onTocPressed,
      onFontPressed: onFontPressed,
      onBookmarkPressed: onBookmarkPressed,
      onSearchPressed: onSearchPressed,
      onSeekFraction: onSeekFraction,
    );
  }
}

/// Unified bottom reader chrome: progress/seek controls above the action row.
///
/// It intentionally keeps seek state local: dragging the thumb does not call
/// JS on every tick, only `onChangeEnd` calls `goToFraction(...)`.
class _ReaderBottomChrome extends StatefulWidget {
  const _ReaderBottomChrome({
    required this.visible,
    required this.progress,
    required this.chapterTitle,
    required this.chapterCurrentPage,
    required this.chapterTotalPages,
    required this.sourceType,
    required this.format,
    required this.panelColor,
    required this.textColor,
    required this.accentColor,
    required this.dividerColor,
    required this.foregroundColor,
    required this.bookmarkActive,
    required this.showTocAction,
    required this.showFontAction,
    required this.showBookmarkAction,
    required this.showSearchAction,
    this.onBack,
    this.onTocPressed,
    this.onFontPressed,
    this.onBookmarkPressed,
    this.onSearchPressed,
    required this.onSeekFraction,
  });

  final bool visible;
  final double progress;
  final String? chapterTitle;
  final int? chapterCurrentPage;
  final int? chapterTotalPages;
  final SourceType sourceType;
  final BookFormat? format;
  final Color panelColor;
  final Color textColor;
  final Color accentColor;
  final Color dividerColor;
  final Color foregroundColor;
  final bool bookmarkActive;
  final bool showTocAction;
  final bool showFontAction;
  final bool showBookmarkAction;
  final bool showSearchAction;
  final VoidCallback? onBack;
  final VoidCallback? onTocPressed;
  final VoidCallback? onFontPressed;
  final VoidCallback? onBookmarkPressed;
  final VoidCallback? onSearchPressed;
  final ValueChanged<double> onSeekFraction;

  @override
  State<_ReaderBottomChrome> createState() => _ReaderBottomChromeState();
}

class _ReaderBottomChromeState extends State<_ReaderBottomChrome> {
  /// Local override for smooth drag and for the short post-release window
  /// before foliate-js reports the new snapped location back to the bloc.
  double? _dragValue;
  bool _isDragging = false;
  Timer? _dragReleaseTimer;

  static const Duration _dragReleaseTimeout = Duration(milliseconds: 600);
  static const double _dragSettleEpsilon = 0.005;

  @override
  void dispose() {
    _dragReleaseTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(_ReaderBottomChrome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isDragging) return;
    final dragValue = _dragValue;
    if (dragValue == null) return;
    final displayedValue = readerSliderValue(
      sourceType: widget.sourceType,
      progress: widget.progress,
      currentPage: widget.chapterCurrentPage,
      totalPages: widget.chapterTotalPages,
    );
    if ((displayedValue - dragValue).abs() <= _dragSettleEpsilon) {
      _dragReleaseTimer?.cancel();
      _dragReleaseTimer = null;
      setState(() => _dragValue = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chromeAnimCurve = widget.visible
        ? _kChromeAnimCurve
        : _kChromeHideAnimCurve;
    final displayedValue = readerSliderValue(
      sourceType: widget.sourceType,
      progress: widget.progress,
      currentPage: widget.chapterCurrentPage,
      totalPages: widget.chapterTotalPages,
    );
    final sliderValue = snappedReaderSeekProgress(
      sourceType: widget.sourceType,
      progress: _dragValue ?? displayedValue,
      totalPages: widget.chapterTotalPages,
    );
    final sliderDivisions = readerSliderDivisions(
      sourceType: widget.sourceType,
      totalPages: widget.chapterTotalPages,
    );
    final mutedText = widget.textColor.withValues(alpha: 0.7);
    final displayedText = readerProgressLabel(
      sourceType: widget.sourceType,
      format: widget.format,
      progress: sliderValue,
      chapterCurrentPage: widget.chapterCurrentPage,
      chapterTotalPages: widget.chapterTotalPages,
      isDragging: _dragValue != null,
    );

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        ignoring: !widget.visible,
        child: AnimatedSlide(
          offset: widget.visible ? Offset.zero : const Offset(0, 1),
          duration: _kChromeAnimDuration,
          curve: chromeAnimCurve,
          child: AnimatedOpacity(
            opacity: widget.visible ? 1 : 0,
            duration: _kChromeAnimDuration,
            curve: chromeAnimCurve,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: widget.panelColor,
                boxShadow: AppShadows.panelUp,
                border: Border(
                  top: BorderSide(
                    color: widget.dividerColor,
                    width: 1 / MediaQuery.devicePixelRatioOf(context),
                  ),
                ),
              ),
              child: AppBottomSafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.sm,
                        AppSpacing.lg,
                        0,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    widget.chapterTitle ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.text.readerChromeLabel
                                        .copyWith(
                                          color: mutedText,
                                        ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Text(
                                  displayedText,
                                  style: context.text.readerChromeNumber
                                      .copyWith(
                                        color: mutedText,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            height: 30,
                            child: SliderTheme(
                              data: SliderThemeData(
                                trackHeight: 3,
                                activeTrackColor: widget.accentColor,
                                inactiveTrackColor: widget.dividerColor,
                                thumbColor: widget.accentColor,
                                overlayColor: widget.accentColor.withValues(
                                  alpha: 0.16,
                                ),
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 6,
                                ),
                                overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 14,
                                ),
                                trackShape: const RoundedRectSliderTrackShape(),
                              ),
                              child: Slider(
                                value: sliderValue,
                                divisions: sliderDivisions,
                                onChangeStart: (v) {
                                  final seekValue = snappedReaderSeekProgress(
                                    sourceType: widget.sourceType,
                                    progress: v,
                                    totalPages: widget.chapterTotalPages,
                                  );
                                  setState(() {
                                    _isDragging = true;
                                    _dragValue = seekValue;
                                  });
                                },
                                onChanged: (v) {
                                  final seekValue = snappedReaderSeekProgress(
                                    sourceType: widget.sourceType,
                                    progress: v,
                                    totalPages: widget.chapterTotalPages,
                                  );
                                  setState(() => _dragValue = seekValue);
                                },
                                onChangeEnd: (v) {
                                  final seekValue = snappedReaderSeekProgress(
                                    sourceType: widget.sourceType,
                                    progress: v,
                                    totalPages: widget.chapterTotalPages,
                                  );
                                  widget.onSeekFraction(seekValue);
                                  _dragReleaseTimer?.cancel();
                                  _dragReleaseTimer = Timer(
                                    _dragReleaseTimeout,
                                    () {
                                      if (!mounted) return;
                                      _dragReleaseTimer = null;
                                      if (_dragValue != null) {
                                        setState(() => _dragValue = null);
                                      }
                                    },
                                  );
                                  setState(() {
                                    _isDragging = false;
                                    _dragValue = seekValue;
                                  });
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: AppSizes.navBarHeight,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                        ),
                        child: Row(
                          children: [
                            _ReaderChromeIconButton(
                              icon: AppIcons.back,
                              iconSize: AppIconSize.lg,
                              tooltip: 'Back',
                              foregroundColor: widget.foregroundColor,
                              onPressed: widget.onBack,
                            ),
                            if (widget.showTocAction) ...[
                              const SizedBox(width: AppSpacing.sm),
                              _ReaderChromeIconButton(
                                icon: AppIcons.toc,
                                tooltip: 'Contents',
                                foregroundColor: widget.foregroundColor,
                                onPressed: widget.onTocPressed,
                              ),
                            ],
                            const Spacer(),
                            ..._buildTrailingActions(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildTrailingActions() {
    final buttons = <Widget>[];

    void addButton(Widget button) {
      if (buttons.isNotEmpty) {
        buttons.add(const SizedBox(width: AppSpacing.sm));
      }
      buttons.add(button);
    }

    if (widget.showFontAction) {
      addButton(
        _ReaderChromeIconButton(
          icon: AppIcons.font,
          tooltip: 'Font',
          foregroundColor: widget.foregroundColor,
          onPressed: widget.onFontPressed,
        ),
      );
    }

    if (widget.showBookmarkAction) {
      addButton(
        _ReaderBookmarkIconButton(
          active: widget.bookmarkActive,
          tooltip: widget.bookmarkActive ? 'Remove bookmark' : 'Bookmark',
          foregroundColor: widget.foregroundColor,
          activeColor: widget.accentColor,
          onPressed: widget.onBookmarkPressed,
        ),
      );
    }

    if (widget.showSearchAction) {
      addButton(
        _ReaderChromeIconButton(
          icon: AppIcons.search,
          tooltip: 'Search',
          foregroundColor: widget.foregroundColor,
          onPressed: widget.onSearchPressed,
        ),
      );
    }

    return buttons;
  }
}

class _ReaderTocDrawerDriver extends StatelessWidget {
  const _ReaderTocDrawerDriver({
    required this.visible,
    required this.onClose,
    required this.onItemSelected,
    required this.onBookmarkSelected,
  });

  final bool visible;
  final VoidCallback onClose;
  final ValueChanged<ReaderTocItem> onItemSelected;
  final ValueChanged<SourceBookmark> onBookmarkSelected;

  @override
  Widget build(BuildContext context) {
    final tocItems = context.select<ReaderBloc, List<ReaderTocItem>>(
      (b) => b.state.tocItems,
    );
    final bookmarks = context.select<ReaderBloc, List<SourceBookmark>>(
      (b) => b.state.bookmarks,
    );
    final colors = context.colors;

    return _ReaderTocDrawer(
      visible: visible,
      tocItems: tocItems,
      bookmarks: bookmarks,
      panelColor: colors.surface,
      dividerColor: colors.outlineVariant,
      onClose: onClose,
      onItemSelected: onItemSelected,
      onBookmarkSelected: onBookmarkSelected,
    );
  }
}

class _ReaderTocDrawer extends StatelessWidget {
  const _ReaderTocDrawer({
    required this.visible,
    required this.tocItems,
    required this.bookmarks,
    required this.panelColor,
    required this.dividerColor,
    required this.onClose,
    required this.onItemSelected,
    required this.onBookmarkSelected,
  });

  final bool visible;
  final List<ReaderTocItem> tocItems;
  final List<SourceBookmark> bookmarks;
  final Color panelColor;
  final Color dividerColor;
  final VoidCallback onClose;
  final ValueChanged<ReaderTocItem> onItemSelected;
  final ValueChanged<SourceBookmark> onBookmarkSelected;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedSlide(
          offset: visible ? Offset.zero : const Offset(-1, 0),
          duration: _kChromeAnimDuration,
          curve: _kChromeAnimCurve,
          child: Material(
            color: panelColor,
            elevation: 0,
            child: SafeArea(
              bottom: false,
              child: _ReaderTocDrawerContent(
                tocItems: tocItems,
                bookmarks: bookmarks,
                onClose: onClose,
                onItemSelected: onItemSelected,
                onBookmarkSelected: onBookmarkSelected,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReaderTocDrawerContent extends StatefulWidget {
  const _ReaderTocDrawerContent({
    required this.tocItems,
    required this.bookmarks,
    required this.onClose,
    required this.onItemSelected,
    required this.onBookmarkSelected,
  });

  final List<ReaderTocItem> tocItems;
  final List<SourceBookmark> bookmarks;
  final VoidCallback onClose;
  final ValueChanged<ReaderTocItem> onItemSelected;
  final ValueChanged<SourceBookmark> onBookmarkSelected;

  @override
  State<_ReaderTocDrawerContent> createState() =>
      _ReaderTocDrawerContentState();
}

class _ReaderTocDrawerContentState extends State<_ReaderTocDrawerContent> {
  final _chaptersSearchController = TextEditingController();
  final _bookmarksSearchController = TextEditingController();
  String _chaptersQuery = '';
  String _bookmarksQuery = '';

  @override
  void dispose() {
    _chaptersSearchController.dispose();
    _bookmarksSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.xs,
              AppSpacing.xs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Contents',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleLarge.copyWith(
                      color: colors.onSurface,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(AppIcons.close, size: AppIconSize.md),
                  tooltip: 'Close',
                  style: _readerDrawerCloseButtonStyle,
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),
          TabBar(
            tabs: const [
              Tab(text: 'Chapters'),
              Tab(text: 'Bookmarks'),
            ],
            labelColor: colors.onSurface,
            unselectedLabelColor: colors.onSurfaceVariant,
            indicatorColor: colors.primary,
          ),
          Expanded(
            child: TabBarView(
              children: [
                _ReaderTocTab(
                  controller: _chaptersSearchController,
                  query: _chaptersQuery,
                  hintText: 'Search chapters',
                  items: widget.tocItems,
                  onQueryChanged: (value) {
                    setState(() => _chaptersQuery = value);
                  },
                  onItemSelected: widget.onItemSelected,
                ),
                _ReaderBookmarksTab(
                  controller: _bookmarksSearchController,
                  query: _bookmarksQuery,
                  bookmarks: widget.bookmarks,
                  onQueryChanged: (value) {
                    setState(() => _bookmarksQuery = value);
                  },
                  onBookmarkSelected: widget.onBookmarkSelected,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReaderTocTab extends StatelessWidget {
  const _ReaderTocTab({
    required this.controller,
    required this.query,
    required this.hintText,
    required this.items,
    required this.onQueryChanged,
    required this.onItemSelected,
  });

  final TextEditingController controller;
  final String query;
  final String hintText;
  final List<ReaderTocItem> items;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<ReaderTocItem> onItemSelected;

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = query.trim().toLowerCase();
    final listBottomPadding = _readerDrawerListBottomPadding(context);
    final filteredItems = normalizedQuery.isEmpty
        ? items
        : [
            for (final item in items)
              if (item.label.toLowerCase().contains(normalizedQuery)) item,
          ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: SearchField(
            controller: controller,
            hintText: hintText,
            onChanged: onQueryChanged,
          ),
        ),
        Expanded(
          child: _ReaderDrawerContentFrame(
            child: filteredItems.isEmpty
                ? _ReaderDrawerEmptyState(
                    message: items.isEmpty
                        ? 'No chapters found'
                        : 'No matching chapters',
                  )
                : ScrollEdgeFadeStack(
                    child: ListView.builder(
                      padding: EdgeInsets.only(bottom: listBottomPadding),
                      itemCount: filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = filteredItems[index];
                        return _ReaderTocListTile(
                          item: item,
                          onTap: () => onItemSelected(item),
                        );
                      },
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _ReaderTocListTile extends StatelessWidget {
  const _ReaderTocListTile({
    required this.item,
    required this.onTap,
  });

  final ReaderTocItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final leftInset =
        AppSpacing.md + (item.level - 1).clamp(0, 4) * AppSpacing.md;

    return ListTile(
      contentPadding: EdgeInsets.only(
        left: leftInset.toDouble(),
        right: AppSpacing.md,
        top: AppSpacing.xxs,
        bottom: AppSpacing.xxs,
      ),
      minVerticalPadding: AppSpacing.xs,
      title: Text(
        item.label.isEmpty ? 'Untitled chapter' : item.label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: context.text.bodyMedium.copyWith(color: colors.onSurface),
      ),
      onTap: onTap,
    );
  }
}

class _ReaderBookmarksTab extends StatelessWidget {
  const _ReaderBookmarksTab({
    required this.controller,
    required this.query,
    required this.bookmarks,
    required this.onQueryChanged,
    required this.onBookmarkSelected,
  });

  final TextEditingController controller;
  final String query;
  final List<SourceBookmark> bookmarks;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<SourceBookmark> onBookmarkSelected;

  @override
  Widget build(BuildContext context) {
    final listBottomPadding = _readerDrawerListBottomPadding(context);
    final filteredBookmarks = filterReaderBookmarks(bookmarks, query);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: SearchField(
            controller: controller,
            hintText: 'Search bookmarks',
            onChanged: onQueryChanged,
          ),
        ),
        Expanded(
          child: _ReaderDrawerContentFrame(
            child: filteredBookmarks.isEmpty
                ? _ReaderDrawerEmptyState(
                    message: bookmarks.isEmpty
                        ? 'No bookmarks yet'
                        : 'No matching bookmarks',
                  )
                : ScrollEdgeFadeStack(
                    child: ListView.builder(
                      padding: EdgeInsets.only(bottom: listBottomPadding),
                      itemCount: filteredBookmarks.length,
                      itemBuilder: (context, index) {
                        final bookmark = filteredBookmarks[index];
                        return _ReaderBookmarkListTile(
                          bookmark: bookmark,
                          onTap: () => onBookmarkSelected(bookmark),
                        );
                      },
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _ReaderBookmarkListTile extends StatelessWidget {
  const _ReaderBookmarkListTile({
    required this.bookmark,
    required this.onTap,
  });

  final SourceBookmark bookmark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final chapterTitle = bookmark.chapterTitle;
    final content = bookmark.content.trim();
    final percentage = (bookmark.progress * 100).clamp(0, 100).round();

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xxs,
      ),
      minVerticalPadding: AppSpacing.xs,
      leading: Icon(
        AppIcons.bookmark,
        size: AppIconSize.sm,
        color: colors.primary,
      ),
      title: Text(
        content.isEmpty ? 'Bookmarked page' : content,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: context.text.bodyMedium.copyWith(color: colors.onSurface),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xxs),
        child: Text(
          [
            if (chapterTitle != null && chapterTitle.isNotEmpty) chapterTitle,
            '$percentage%',
          ].join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.text.bodySmall.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ),
      onTap: onTap,
    );
  }
}

class _ReaderSearchDrawer extends StatelessWidget {
  const _ReaderSearchDrawer({
    required this.visible,
    required this.onClose,
    required this.onSearch,
    required this.onClearSearch,
    required this.onResultSelected,
  });

  final bool visible;
  final VoidCallback onClose;
  final Stream<ReaderSearchEvent> Function(String query) onSearch;
  final VoidCallback onClearSearch;
  final ValueChanged<ReaderSearchResult> onResultSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedSlide(
          offset: visible ? Offset.zero : const Offset(-1, 0),
          duration: _kChromeAnimDuration,
          curve: _kChromeAnimCurve,
          child: Material(
            color: colors.surface,
            elevation: 0,
            child: SafeArea(
              bottom: false,
              child: _ReaderSearchDrawerContent(
                visible: visible,
                onClose: onClose,
                onSearch: onSearch,
                onClearSearch: onClearSearch,
                onResultSelected: onResultSelected,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReaderSearchDrawerContent extends StatefulWidget {
  const _ReaderSearchDrawerContent({
    required this.visible,
    required this.onClose,
    required this.onSearch,
    required this.onClearSearch,
    required this.onResultSelected,
  });

  final bool visible;
  final VoidCallback onClose;
  final Stream<ReaderSearchEvent> Function(String query) onSearch;
  final VoidCallback onClearSearch;
  final ValueChanged<ReaderSearchResult> onResultSelected;

  @override
  State<_ReaderSearchDrawerContent> createState() =>
      _ReaderSearchDrawerContentState();
}

class _ReaderSearchDrawerContentState
    extends State<_ReaderSearchDrawerContent> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void didUpdateWidget(covariant _ReaderSearchDrawerContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && !oldWidget.visible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    } else if (!widget.visible && oldWidget.visible) {
      _focusNode.unfocus();
      _controller.clear();
      context.read<ReaderSearchCubit>().reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    context.read<ReaderSearchCubit>().queryChanged(
      value,
      searchBook: widget.onSearch,
    );
  }

  void _selectRecentQuery(String query) {
    _controller.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    _focusNode.requestFocus();
    context.read<ReaderSearchCubit>().recentQuerySelected(
      query,
      searchBook: widget.onSearch,
    );
  }

  void _removeRecentQuery(String query) {
    context.read<ReaderSearchCubit>().recentQueryRemoved(query);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final listBottomPadding = _readerDrawerListBottomPadding(context);

    return BlocListener<ReaderSearchCubit, ReaderSearchState>(
      listenWhen: (previous, current) =>
          previous.clearSearchToken != current.clearSearchToken,
      listener: (_, _) => widget.onClearSearch(),
      child: BlocBuilder<ReaderSearchCubit, ReaderSearchState>(
        builder: (context, state) {
          final query = state.query.trim();
          final canSearch = query.length >= ReaderSearchCubit.minQueryLength;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.xs,
                  AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Search',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.titleLarge.copyWith(
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(AppIcons.close, size: AppIconSize.md),
                      tooltip: 'Close',
                      style: _readerDrawerCloseButtonStyle,
                      onPressed: widget.onClose,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: SearchField(
                  controller: _controller,
                  focusNode: _focusNode,
                  hintText: 'Search in book',
                  onChanged: _onQueryChanged,
                ),
              ),
              if (state.isLoading)
                LinearProgressIndicator(
                  minHeight: 2,
                  value: state.progress > 0 && state.progress < 1
                      ? state.progress
                      : null,
                ),
              Expanded(
                child: _ReaderDrawerContentFrame(
                  child: state.errorMessage != null
                      ? _ReaderDrawerEmptyState(message: state.errorMessage!)
                      : !canSearch
                      ? query.isEmpty && state.recentQueries.isNotEmpty
                            ? _ReaderRecentSearchesList(
                                queries: state.recentQueries,
                                bottomPadding: listBottomPadding,
                                onQuerySelected: _selectRecentQuery,
                                onQueryRemoved: _removeRecentQuery,
                              )
                            : const _ReaderDrawerEmptyState(
                                message: 'Type at least 2 characters to search',
                              )
                      : state.results.isEmpty && !state.isLoading
                      ? const _ReaderDrawerEmptyState(
                          message: 'No results found',
                        )
                      : ScrollEdgeFadeStack(
                          child: ListView.builder(
                            padding: EdgeInsets.only(
                              bottom: listBottomPadding,
                            ),
                            itemCount: state.results.length,
                            itemBuilder: (context, index) {
                              final result = state.results[index];
                              return _ReaderSearchResultTile(
                                result: result,
                                onTap: () => widget.onResultSelected(result),
                              );
                            },
                          ),
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

class _ReaderRecentSearchesList extends StatelessWidget {
  const _ReaderRecentSearchesList({
    required this.queries,
    required this.bottomPadding,
    required this.onQuerySelected,
    required this.onQueryRemoved,
  });

  final List<String> queries;
  final double bottomPadding;
  final ValueChanged<String> onQuerySelected;
  final ValueChanged<String> onQueryRemoved;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ScrollEdgeFadeStack(
      child: ListView.builder(
        padding: EdgeInsets.only(bottom: bottomPadding),
        itemCount: queries.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.xs,
              ),
              child: Text(
                'Recent searches',
                style: context.text.labelMedium.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            );
          }

          final query = queries[index - 1];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xxs,
            ),
            minVerticalPadding: AppSpacing.xs,
            leading: Icon(
              AppIcons.clock,
              size: AppIconSize.xs,
              color: colors.onSurfaceVariant,
            ),
            title: Text(
              query,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodyMedium.copyWith(
                color: colors.onSurface,
              ),
            ),
            trailing: IconButton(
              icon: const Icon(AppIcons.close, size: AppIconSize.xs),
              tooltip: 'Remove from history',
              style: _readerDrawerCloseButtonStyle,
              onPressed: () => onQueryRemoved(query),
            ),
            onTap: () => onQuerySelected(query),
          );
        },
      ),
    );
  }
}

class _ReaderSearchResultTile extends StatelessWidget {
  const _ReaderSearchResultTile({
    required this.result,
    required this.onTap,
  });

  final ReaderSearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final chapterTitle = result.chapterTitle;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xxs,
      ),
      minVerticalPadding: AppSpacing.xs,
      title: Text(
        chapterTitle == null || chapterTitle.isEmpty
            ? 'Search result'
            : chapterTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.text.bodySmall.copyWith(
          color: colors.onSurfaceVariant,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: RichText(
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(
            style: context.text.bodyMedium.copyWith(color: colors.onSurface),
            children: [
              TextSpan(text: result.excerpt.pre),
              TextSpan(
                text: result.excerpt.match,
                style: context.text.bodyMedium.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextSpan(text: result.excerpt.post),
            ],
          ),
        ),
      ),
      onTap: onTap,
    );
  }
}

class _ReaderDrawerContentFrame extends StatelessWidget {
  const _ReaderDrawerContentFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: context.colors.outlineVariant,
            width: 1 / MediaQuery.devicePixelRatioOf(context),
          ),
        ),
      ),
      child: child,
    );
  }
}

class _ReaderDrawerEmptyState extends StatelessWidget {
  const _ReaderDrawerEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: context.text.bodyMedium.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Reads selection from [ReaderSelectionCubit] and source info from
/// [ReaderBloc] to show/hide the text-action context panel.
class _ContextPanelDriver extends StatelessWidget {
  const _ContextPanelDriver({required this.textActions});

  final List<TextAction> textActions;

  @override
  Widget build(BuildContext context) {
    final sel = context.select<ReaderSelectionCubit, ReaderSelectionState>(
      (c) => c.state,
    );
    final sourceId = context.select<ReaderBloc, String?>(
      (b) => b.state.sourceId,
    );

    if (!sel.hasSelection || sourceId == null) {
      return const SizedBox.shrink();
    }

    final bloc = context.read<ReaderBloc>();
    final colors = context.colors;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: _ContextPanel(
        selectedText: sel.selectedText,
        sourceId: sourceId,
        selectionCfiRange: sel.cfiRange,
        selectionPageNumber: sel.pageNumber,
        selectionScrollOffset: sel.scrollOffset,
        textActions: textActions,
        panelColor: colors.surface,
        iconColor: colors.onSurface,
        dividerColor: colors.outlineVariant,
        onActionCompleted: () {
          if (!bloc.isClosed) bloc.add(const ReaderHighlightsRefreshed());
        },
        onActionError: (e, st) {
          if (!bloc.isClosed) bloc.reportError(e, st);
        },
      ),
    );
  }
}

/// Renders the review reminder banner when [ReaderReviewReminderCubit] reports
/// due items. Positions itself above the context panel when text is selected.
class _ReviewReminderDriver extends StatelessWidget {
  const _ReviewReminderDriver();

  @override
  Widget build(BuildContext context) {
    final show = context.select<ReaderReviewReminderCubit, bool>(
      (c) => c.state.showReminder,
    );

    if (!show) return const SizedBox.shrink();

    final hasSelection = context.select<ReaderSelectionCubit, bool>(
      (c) => c.state.hasSelection,
    );
    final sourceId = context.select<ReaderBloc, String?>(
      (b) => b.state.sourceId,
    );
    final reminderCubit = context.read<ReaderReviewReminderCubit>();
    final onStartMiniReview = _ReaderCallbacksScope.of(
      context,
    )?.onStartMiniReview;

    return Positioned(
      left: AppSpacing.md,
      right: AppSpacing.md,
      bottom: hasSelection ? _kContextPanelHeight : AppSpacing.md,
      child: _ReviewReminderBanner(
        onReview: () {
          reminderCubit.dismiss();
          if (sourceId != null) {
            onStartMiniReview?.call(context, sourceId);
          }
        },
        onDismiss: reminderCubit.dismiss,
      ),
    );
  }
}

/// Always-on "page X / Y" indicator for comics — CBZ readers expect a
/// constant pager hint, and tapping chrome for every page-turn is friction.
///
/// Subscribes only to the chapter-page pair (which for CBZ maps 1:1
/// to comic page index / total) and a couple of visibility gates.
/// Renders nothing when:
///   * the format isn't CBZ — books and PDFs do not need the comic page
///     counter,
///   * the chrome panel is visible — the action bar should own the bottom
///     visual area,
///   * a text selection is active — the context panel takes the
///     bottom of the screen and the overlay would clutter it,
///   * page metrics haven't arrived yet (first `onRelocated` not
///     fired).
///
/// Position: anchored near the bottom safe area while chrome is hidden.
/// When chrome is shown, the overlay is hidden so it does not compete with
/// the bottom action bar.
class _ComicProgressOverlayDriver extends StatelessWidget {
  const _ComicProgressOverlayDriver();

  @override
  Widget build(BuildContext context) {
    final format = context.select<ReaderBloc, BookFormat?>(
      (b) => b.state.book?.format,
    );
    if (format != BookFormat.cbz) return const SizedBox.shrink();

    final chromeVisible = context.select<ReaderUiCubit, bool>(
      (c) => c.state.chromeVisible,
    );
    final hasSelection = context.select<ReaderSelectionCubit, bool>(
      (c) => c.state.hasSelection,
    );
    if (chromeVisible || hasSelection) return const SizedBox.shrink();

    final current = context.select<ReaderBloc, int?>(
      (b) => b.state.chapterCurrentPage,
    );
    final total = context.select<ReaderBloc, int?>(
      (b) => b.state.chapterTotalPages,
    );
    if (current == null || total == null || total <= 0) {
      return const SizedBox.shrink();
    }

    final displayed = displayZeroIndexedPage(current, total);
    final colors = context.colors;
    final bottomInset = appBottomSafeInset(context);
    return Positioned(
      left: 0,
      right: 0,
      bottom: bottomInset + AppSpacing.md,
      child: Center(
        child: _ComicProgressOverlay(
          text: '$displayed / $total',
          // Worst-case width: when current reaches the last page the
          // string is "total / total" — wider than any earlier
          // page. We hand it down so the overlay can reserve the
          // right amount of space up front.
          maxText: '$total / $total',
          panelColor: colors.surface,
          textColor: colors.onSurfaceVariant,
          dividerColor: colors.outlineVariant,
        ),
      ),
    );
  }
}

/// Pill-shaped read-only "X / Y" badge for the comic-progress overlay.
/// Themed off the reader's panel/divider colours so it sits naturally
/// against any of the page backgrounds (sepia, dark, paper).
///
/// Width is reserved for the worst-case content (`maxText`, e.g. "30 /
/// 30") via an invisible placeholder layered behind the live text.
/// Tabular figures alone aren't enough — they equalise digit widths but
/// not digit *counts*, so "1 / 30" is one glyph narrower than "30 /
/// 30" and the pill would visibly grow as the user moves through the
/// comic. Placeholder + `Stack` is the Flutter-idiomatic "size to max
/// content" pattern: width comes from real text measurement, not from
/// a hand-picked SizedBox value that would drift out of sync with the
/// font.
class _ComicProgressOverlay extends StatelessWidget {
  const _ComicProgressOverlay({
    required this.text,
    required this.maxText,
    required this.panelColor,
    required this.textColor,
    required this.dividerColor,
  });

  final String text;
  final String maxText;
  final Color panelColor;
  final Color textColor;
  final Color dividerColor;

  @override
  Widget build(BuildContext context) {
    final style = context.text.readerChromeNumber.copyWith(
      color: textColor,
    );

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        // Slightly translucent so the comic page peeks through —
        // overlay reads as "info chrome" rather than a solid panel.
        color: panelColor.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: dividerColor),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Invisible width-reservation. `Visibility.maintain*` would
          // also work but Opacity is the lighter option here since we
          // never want it to participate in semantics or hit-testing.
          Opacity(
            opacity: 0,
            child: ExcludeSemantics(child: Text(maxText, style: style)),
          ),
          Text(text, style: style),
        ],
      ),
    );
  }
}

class _ReaderWebViewBody extends StatefulWidget {
  const _ReaderWebViewBody({
    required this.serverPort,
    required this.readerTheme,
    this.webViewKey,
    this.onPositionChanged,
  });

  final int serverPort;
  final ReaderThemeData readerTheme;

  /// Optional GlobalKey — the parent state holds it so progress chrome can
  /// reach into [BookReaderWebViewState] for `goToFraction`.
  final GlobalKey<BookReaderWebViewState>? webViewKey;

  /// Side-effect hook for UI-only reader chrome state. Bloc persistence stays
  /// inside this widget; parent uses this to clear transient search overlays.
  final ValueChanged<BookPosition>? onPositionChanged;

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
  /// rebuilds for many reasons unrelated to highlights (theme tap,
  /// font/layout change in ReaderAppearanceCubit, the loading-scrim flip,
  /// etc.); without a cache the `.map(...).toList()` re-allocates the
  /// `ReaderHighlight` list every time.
  ///
  /// Cache lives on the widget state (not on `ReaderState`) on purpose.
  /// `ReaderState` instances churn on every page-turn via `copyWith`,
  /// which would invalidate a `late final` cache on each tick. The
  /// underlying `state.highlights` reference, in contrast, only
  /// changes on `ReaderHighlightsRefreshed` — so widget-state cache
  /// keyed on `identical(...)` of that reference hits on every
  /// non-highlights rebuild.
  List<Highlight>? _lastHighlightsRef;
  List<ReaderHighlight>? _cachedReaderHighlights;
  List<SourceBookmark>? _lastBookmarksRef;
  List<ReaderBookmark>? _cachedReaderBookmarks;

  List<ReaderHighlight> _readerHighlightsFor(List<Highlight> source) {
    final cached = _cachedReaderHighlights;
    if (cached != null && identical(source, _lastHighlightsRef)) {
      return cached;
    }
    _lastHighlightsRef = source;
    return _cachedReaderHighlights = [
      for (final h in source)
        ReaderHighlight(id: h.id, text: h.text, cfiRange: h.cfiRange),
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
    final highlights = _readerHighlightsFor(highlightsState);
    final bookmarks = _readerBookmarksFor(bookmarksState);

    void onTapped(double x, double _) {
      switch (readerTapActionFor(
        x: x,
        chromeVisible: uiCubit.state.chromeVisible,
      )) {
        case ReaderTapAction.previousPage:
          widget.webViewKey?.currentState?.prevPage();
        case ReaderTapAction.nextPage:
          widget.webViewKey?.currentState?.nextPage();
        case ReaderTapAction.toggleChrome:
          uiCubit.toggleChrome();
      }
    }

    final appearance = context
        .select<ReaderAppearanceCubit, ReaderAppearancePreferences>(
          (c) => c.state.effectiveAppearance,
        );
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
      highlights: highlights,
      bookmarks: bookmarks,
      onReady: () {
        if (mounted && !_foliateReady) {
          setState(() => _foliateReady = true);
        }
      },
      onPositionChanged: (position) {
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
        uiCubit.hideChrome();
        selectionCubit.select(
          text: selection.text,
          cfiRange: selection.cfiRange,
        );
      },
      onTextDeselected: () => selectionCubit.deselect(),
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

class _ContextPanel extends StatelessWidget {
  const _ContextPanel({
    required this.selectedText,
    required this.sourceId,
    required this.textActions,
    required this.panelColor,
    required this.iconColor,
    required this.dividerColor,
    required this.onActionCompleted,
    required this.onActionError,
    this.selectionCfiRange,
    this.selectionPageNumber,
    this.selectionScrollOffset,
  });

  final String selectedText;
  final String sourceId;
  final List<TextAction> textActions;
  final Color panelColor;
  final Color iconColor;
  final Color dividerColor;
  final VoidCallback onActionCompleted;
  final void Function(Object error, StackTrace stack) onActionError;
  final String? selectionCfiRange;
  final int? selectionPageNumber;
  final double? selectionScrollOffset;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: panelColor,
      elevation: 0,
      child: AppBottomSafeArea(
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: dividerColor)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: textActions.map((action) {
                return IconButton(
                  icon: Icon(action.icon, color: iconColor),
                  tooltip: action.label,
                  onPressed: () async {
                    try {
                      await action.onExecute(
                        context,
                        TextSelectionContext(
                          selectedText: selectedText,
                          sourceId: sourceId,
                          sourceType: SourceType.book,
                          cfiRange: selectionCfiRange,
                          pageNumber: selectionPageNumber,
                          scrollOffset: selectionScrollOffset,
                        ),
                      );
                      onActionCompleted();
                    } catch (e, st) {
                      onActionError(e, st);
                    }
                  },
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReviewReminderBanner extends StatelessWidget {
  const _ReviewReminderBanner({
    required this.onReview,
    required this.onDismiss,
  });

  final VoidCallback onReview;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            const Icon(AppIcons.practice, size: AppIconSize.sm),
            const SizedBox(width: AppSpacing.sm),
            const Expanded(child: Text('You have items to review')),
            TextButton(onPressed: onReview, child: const Text('Review')),
            IconButton(
              icon: const Icon(AppIcons.close, size: AppIconSize.sm),
              onPressed: onDismiss,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}
