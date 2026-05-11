import 'dart:async';

import 'package:book_repository/book_repository.dart';
import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:highlight_repository/highlight_repository.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:reader_webview/reader_webview.dart';
import 'package:shared/shared.dart';

import 'book_custom_css.dart';
import 'reader_bloc.dart';
import 'reader_chrome_cubit.dart';
import 'reader_color_utils.dart';
import 'reader_review_reminder_cubit.dart';
import 'reader_selection_cubit.dart';

/// Approximate height of the context panel, used to offset the review banner.
const _kContextPanelHeight = 80.0;

/// Duration and curve for the reader chrome slide animation.
const _kChromeAnimDuration = Duration(milliseconds: 200);
const _kChromeAnimCurve = Curves.easeOutCubic;
const _kBookSearchMinQueryLength = 2;

final _readerDrawerCloseButtonStyle = IconButton.styleFrom(
  backgroundColor: Colors.transparent,
  disabledBackgroundColor: Colors.transparent,
  hoverColor: Colors.transparent,
  focusColor: Colors.transparent,
  highlightColor: Colors.transparent,
);

/// foliate-js's "location" granularity in bytes — the divisor it uses for
/// `bookCurrentPage = floor(currentBytes / sizePerLoc)`. Hard-coded in
/// `view.js` (`new SectionProgress(book.sections, 1500, 1600)`); mirror
/// it here so the slider can predict the page number during drag.
const _foliateSizePerLoc = 1500;

/// Converts foliate-js's 0-indexed location number into the 1-indexed
/// page count the reader actually shows ("page 1" instead of "page 0"
/// for the start of the book). Clamps to `[1, totalPages]` when we have
/// the total so a glitchy raw value past the end of the book — or a
/// drag-time overshoot from `floor(f × totalPages)` at f=1 — can't
/// surface as `totalPages + 1`.
///
/// Bloc/state keep the raw 0-indexed value so they stay aligned with
/// foliate-js's own arithmetic; this conversion lives in the display
/// layer only.
int _toDisplayPage(int locationIndex, int? totalPages) {
  final oneIndexed = locationIndex + 1;
  if (totalPages != null && totalPages > 0) {
    return oneIndexed.clamp(1, totalPages);
  }
  return oneIndexed;
}

/// Carries the optional review-reminder and mini-review callbacks down the
/// reader widget tree, eliminating prop drilling through 4+ layers.
class _ReaderCallbacksScope extends InheritedWidget {
  const _ReaderCallbacksScope({
    required this.onCheckDueItems,
    required this.onStartMiniReview,
    required super.child,
  });

  final Future<int> Function(String sourceId)? onCheckDueItems;
  final void Function(BuildContext context, String sourceId)? onStartMiniReview;

  static _ReaderCallbacksScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ReaderCallbacksScope>();

  @override
  bool updateShouldNotify(_ReaderCallbacksScope old) =>
      onCheckDueItems != old.onCheckDueItems ||
      onStartMiniReview != old.onStartMiniReview;
}

/// Full-screen reader for a book (route `/reader/:sourceId`).
///
/// Composition only: wires [ReaderBloc] (source + highlights + position
/// persistence), [ReaderChromeCubit] (chrome visibility) and
/// [ReaderSelectionCubit] (text selection) around an internal
/// [_ReaderView], and exposes optional review-reminder callbacks via an
/// [InheritedWidget] instead of prop-drilling. [textActions] follow the
/// plugin contract from `package:shared` — features like Highlight /
/// Flashcard / Translate are wired in the composition root.
class ReaderScreen extends StatelessWidget {
  const ReaderScreen({
    required this.sourceId,
    required this.serverPort,
    required this.bookRepository,
    required this.highlightRepository,
    required this.textActions,
    this.initialSource,
    this.onCheckDueItems,
    this.onStartMiniReview,
    super.key,
  });

  final String sourceId;
  final int serverPort;
  final BookRepository bookRepository;
  final HighlightRepository highlightRepository;
  final List<TextAction> textActions;
  final Book? initialSource;
  final Future<int> Function(String sourceId)? onCheckDueItems;
  final void Function(BuildContext context, String sourceId)? onStartMiniReview;

  @override
  Widget build(BuildContext context) {
    debugLogScreenBuild('ReaderScreen(sourceId: $sourceId)');

    return _ReaderCallbacksScope(
      onCheckDueItems: onCheckDueItems,
      onStartMiniReview: onStartMiniReview,
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => ReaderBloc(
              bookRepository: bookRepository,
              highlightRepository: highlightRepository,
              initialSource: initialSource?.id == sourceId
                  ? initialSource
                  : null,
            )..add(ReaderSourceLoadRequested(sourceId: sourceId)),
          ),
          BlocProvider(create: (_) => ReaderChromeCubit()),
          BlocProvider(create: (_) => ReaderSelectionCubit()),
        ],
        child: _ReaderView(serverPort: serverPort, textActions: textActions),
      ),
    );
  }
}

class _ReaderView extends StatelessWidget {
  const _ReaderView({required this.serverPort, required this.textActions});

  final int serverPort;
  final List<TextAction> textActions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
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
    return switch (status) {
      ReaderStatus.initial ||
      ReaderStatus.loading => const Center(child: CircularProgressIndicator()),
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
        sourceId: context.read<ReaderBloc>().state.sourceId!,
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
    this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final Color foregroundColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return IconButton(
      icon: Icon(icon, size: AppIconSize.md),
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: disabled
            ? foregroundColor.withValues(alpha: 0.35)
            : foregroundColor,
      ),
    );
  }
}

class _ReadyContent extends StatelessWidget {
  const _ReadyContent({
    required this.sourceId,
    required this.serverPort,
    required this.textActions,
  });

  final String sourceId;
  final int serverPort;
  final List<TextAction> textActions;

  @override
  Widget build(BuildContext context) {
    final callbacks = _ReaderCallbacksScope.of(context);
    return BlocProvider(
      create: (_) => ReaderReviewReminderCubit(
        sourceId: sourceId,
        onCheckDueItems: callbacks?.onCheckDueItems,
      ),
      child: _ReadyContentBody(
        serverPort: serverPort,
        textActions: textActions,
      ),
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
  bool _tocDrawerVisible = false;
  bool _searchDrawerVisible = false;

  void _seekFraction(double fraction) {
    _webViewKey.currentState?.goToFraction(fraction);
  }

  void _openTocDrawer() {
    if (_tocDrawerVisible) return;
    context.read<ReaderChromeCubit>().hide();
    setState(() {
      _tocDrawerVisible = true;
      _searchDrawerVisible = false;
    });
  }

  void _closeTocDrawer({bool restoreChrome = true}) {
    if (!_tocDrawerVisible) return;
    setState(() => _tocDrawerVisible = false);
    if (restoreChrome) context.read<ReaderChromeCubit>().show();
  }

  void _openSearchDrawer() {
    if (_searchDrawerVisible) return;
    context.read<ReaderChromeCubit>().hide();
    setState(() {
      _searchDrawerVisible = true;
      _tocDrawerVisible = false;
    });
  }

  void _closeSearchDrawer({bool restoreChrome = true}) {
    if (!_searchDrawerVisible) return;
    _webViewKey.currentState?.clearSearch();
    setState(() => _searchDrawerVisible = false);
    if (restoreChrome) context.read<ReaderChromeCubit>().show();
  }

  void _goToTocItem(ReaderTocItem item) {
    if (item.href.isEmpty) return;
    _webViewKey.currentState?.goToHref(item.href);
    _closeTocDrawer(restoreChrome: false);
  }

  void _goToSearchResult(ReaderSearchResult result) {
    if (result.cfi.isEmpty) return;
    _webViewKey.currentState?.goToCfi(result.cfi);
    _closeSearchDrawer(restoreChrome: false);
  }

  Future<List<ReaderSearchResult>> _searchBook(String query) async {
    return _webViewKey.currentState?.searchBook(query) ?? const [];
  }

  @override
  Widget build(BuildContext context) {
    final appearance = PreferencesScope.readerAppearanceOf(context);
    // Reader theme drives the book *page* — WebView background and
    // foliate-js customCSS. Chrome (passed-through Stack siblings)
    // pulls colours from the app theme themselves; they don't take
    // a `readerTheme` prop any more.
    final readerTheme = ReaderThemePreset.fromId(appearance.themeId).data;

    return Stack(
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
          ),
        ),
        _ReaderBottomChromeDriver(
          onTocPressed: _openTocDrawer,
          onSearchPressed: _openSearchDrawer,
          onSeekFraction: _seekFraction,
        ),
        const _ComicProgressOverlayDriver(),
        _ContextPanelDriver(textActions: widget.textActions),
        const _ReviewReminderDriver(),
        _ReaderTocDrawerDriver(
          visible: _tocDrawerVisible,
          onClose: _closeTocDrawer,
          onItemSelected: _goToTocItem,
        ),
        _ReaderSearchDrawer(
          visible: _searchDrawerVisible,
          onClose: _closeSearchDrawer,
          onSearch: _searchBook,
          onResultSelected: _goToSearchResult,
        ),
      ],
    );
  }
}

/// Combines chrome visibility from [ReaderChromeCubit], selection state from
/// [ReaderSelectionCubit], and reading progress from [ReaderBloc].
class _ReaderBottomChromeDriver extends StatelessWidget {
  const _ReaderBottomChromeDriver({
    required this.onTocPressed,
    required this.onSearchPressed,
    required this.onSeekFraction,
  });

  final VoidCallback onTocPressed;
  final VoidCallback onSearchPressed;

  /// Forwarded to the slider's drag-end handler. Skips the bloc entirely —
  /// the WebView's `goToFraction` triggers `onRelocated` once the new page
  /// lands and the bloc updates from there.
  final ValueChanged<double> onSeekFraction;

  @override
  Widget build(BuildContext context) {
    final chromeVisible = context.select<ReaderChromeCubit, bool>(
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
    final bookCurrentPage = context.select<ReaderBloc, int?>(
      (b) => b.state.bookCurrentPage,
    );
    final bookTotalPages = context.select<ReaderBloc, int?>(
      (b) => b.state.bookTotalPages,
    );
    final chapterCurrentPage = context.select<ReaderBloc, int?>(
      (b) => b.state.chapterCurrentPage,
    );
    final chapterTotalPages = context.select<ReaderBloc, int?>(
      (b) => b.state.chapterTotalPages,
    );
    final sizeTotal = context.select<ReaderBloc, int?>(
      (b) => b.state.sizeTotal,
    );
    final format = context.select<ReaderBloc, BookFormat?>(
      (b) => b.state.book?.format,
    );
    final colors = context.colors;

    return _ReaderBottomChrome(
      visible: chromeVisible && !hasSelection,
      progress: progress,
      chapterTitle: chapterTitle,
      bookCurrentPage: bookCurrentPage,
      bookTotalPages: bookTotalPages,
      chapterCurrentPage: chapterCurrentPage,
      chapterTotalPages: chapterTotalPages,
      sizeTotal: sizeTotal,
      format: format,
      panelColor: colors.surface,
      textColor: colors.onSurfaceVariant,
      accentColor: colors.primary,
      dividerColor: colors.outlineVariant,
      foregroundColor: colors.onSurface,
      onBack: () => Navigator.of(context).maybePop(),
      onTocPressed: onTocPressed,
      onFontPressed: null,
      onBookmarkPressed: null,
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
    required this.bookCurrentPage,
    required this.bookTotalPages,
    required this.chapterCurrentPage,
    required this.chapterTotalPages,
    required this.sizeTotal,
    required this.format,
    required this.panelColor,
    required this.textColor,
    required this.accentColor,
    required this.dividerColor,
    required this.foregroundColor,
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
  final int? bookCurrentPage;
  final int? bookTotalPages;
  final int? chapterCurrentPage;
  final int? chapterTotalPages;
  final int? sizeTotal;
  final BookFormat? format;
  final Color panelColor;
  final Color textColor;
  final Color accentColor;
  final Color dividerColor;
  final Color foregroundColor;
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
    if ((widget.progress - dragValue).abs() <= _dragSettleEpsilon) {
      _dragReleaseTimer?.cancel();
      _dragReleaseTimer = null;
      setState(() => _dragValue = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clamped = widget.progress.clamp(0.0, 1.0);
    final sliderValue = (_dragValue ?? clamped).clamp(0.0, 1.0);
    final mutedText = widget.textColor.withValues(alpha: 0.7);
    final isComic = widget.format == BookFormat.cbz;

    final int? rawCurrent;
    final int? totalForMode;
    if (isComic) {
      rawCurrent = widget.chapterCurrentPage;
      totalForMode = widget.chapterTotalPages;
    } else {
      rawCurrent = widget.bookCurrentPage;
      totalForMode = widget.bookTotalPages;
    }

    final dragValue = _dragValue;
    final sizeTotal = widget.sizeTotal;
    final int? rawLocation;
    if (dragValue != null) {
      if (!isComic && sizeTotal != null && sizeTotal > 0) {
        rawLocation = (dragValue * sizeTotal / _foliateSizePerLoc).floor();
      } else if (totalForMode != null && totalForMode > 0) {
        rawLocation = (dragValue * totalForMode).floor();
      } else {
        rawLocation = null;
      }
    } else {
      rawLocation = rawCurrent;
    }

    final String displayedText;
    if (rawLocation == null) {
      displayedText = '';
    } else if (isComic && totalForMode != null && totalForMode > 0) {
      final oneIndexed = _toDisplayPage(rawLocation, totalForMode);
      displayedText = '$oneIndexed / $totalForMode';
    } else {
      displayedText = _toDisplayPage(rawLocation, totalForMode).toString();
    }

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        ignoring: !widget.visible,
        child: AnimatedSlide(
          offset: widget.visible ? Offset.zero : const Offset(0, 1),
          duration: _kChromeAnimDuration,
          curve: _kChromeAnimCurve,
          child: AnimatedOpacity(
            opacity: widget.visible ? 1 : 0,
            duration: _kChromeAnimDuration,
            curve: _kChromeAnimCurve,
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
              child: SafeArea(
                top: false,
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
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: mutedText,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Text(
                                  displayedText,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: mutedText,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
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
                                onChangeStart: (v) {
                                  setState(() {
                                    _isDragging = true;
                                    _dragValue = v;
                                  });
                                },
                                onChanged: (v) {
                                  setState(() => _dragValue = v);
                                },
                                onChangeEnd: (v) {
                                  widget.onSeekFraction(v);
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
                                    _dragValue = v;
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
                              tooltip: 'Back',
                              foregroundColor: widget.foregroundColor,
                              onPressed: widget.onBack,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            _ReaderChromeIconButton(
                              icon: AppIcons.toc,
                              tooltip: 'Contents',
                              foregroundColor: widget.foregroundColor,
                              onPressed: widget.onTocPressed,
                            ),
                            const Spacer(),
                            _ReaderChromeIconButton(
                              icon: AppIcons.font,
                              tooltip: 'Font',
                              foregroundColor: widget.foregroundColor,
                              onPressed: widget.onFontPressed,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            _ReaderChromeIconButton(
                              icon: AppIcons.bookmark,
                              tooltip: 'Bookmark',
                              foregroundColor: widget.foregroundColor,
                              onPressed: widget.onBookmarkPressed,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            _ReaderChromeIconButton(
                              icon: AppIcons.search,
                              tooltip: 'Search',
                              foregroundColor: widget.foregroundColor,
                              onPressed: widget.onSearchPressed,
                            ),
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
}

class _ReaderTocDrawerDriver extends StatelessWidget {
  const _ReaderTocDrawerDriver({
    required this.visible,
    required this.onClose,
    required this.onItemSelected,
  });

  final bool visible;
  final VoidCallback onClose;
  final ValueChanged<ReaderTocItem> onItemSelected;

  @override
  Widget build(BuildContext context) {
    final tocItems = context.select<ReaderBloc, List<ReaderTocItem>>(
      (b) => b.state.tocItems,
    );
    final colors = context.colors;

    return _ReaderTocDrawer(
      visible: visible,
      tocItems: tocItems,
      panelColor: colors.surface,
      dividerColor: colors.outlineVariant,
      onClose: onClose,
      onItemSelected: onItemSelected,
    );
  }
}

class _ReaderTocDrawer extends StatelessWidget {
  const _ReaderTocDrawer({
    required this.visible,
    required this.tocItems,
    required this.panelColor,
    required this.dividerColor,
    required this.onClose,
    required this.onItemSelected,
  });

  final bool visible;
  final List<ReaderTocItem> tocItems;
  final Color panelColor;
  final Color dividerColor;
  final VoidCallback onClose;
  final ValueChanged<ReaderTocItem> onItemSelected;

  @override
  Widget build(BuildContext context) {
    final drawerWidth = MediaQuery.sizeOf(context).width < 420
        ? MediaQuery.sizeOf(context).width * 0.86
        : 360.0;

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !visible,
        child: Stack(
          children: [
            AnimatedOpacity(
              opacity: visible ? 1 : 0,
              duration: _kChromeAnimDuration,
              curve: _kChromeAnimCurve,
              child: GestureDetector(
                onTap: onClose,
                behavior: HitTestBehavior.opaque,
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.28),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
            AnimatedSlide(
              offset: visible ? Offset.zero : const Offset(-1, 0),
              duration: _kChromeAnimDuration,
              curve: _kChromeAnimCurve,
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: drawerWidth,
                  child: Material(
                    color: panelColor,
                    elevation: 0,
                    child: SafeArea(
                      right: false,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border(
                            right: BorderSide(color: dividerColor),
                          ),
                        ),
                        child: _ReaderTocDrawerContent(
                          tocItems: tocItems,
                          onClose: onClose,
                          onItemSelected: onItemSelected,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReaderTocDrawerContent extends StatefulWidget {
  const _ReaderTocDrawerContent({
    required this.tocItems,
    required this.onClose,
    required this.onItemSelected,
  });

  final List<ReaderTocItem> tocItems;
  final VoidCallback onClose;
  final ValueChanged<ReaderTocItem> onItemSelected;

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
                  onQueryChanged: (value) {
                    setState(() => _bookmarksQuery = value);
                  },
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
                      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
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
      ),
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
    required this.onQueryChanged,
  });

  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onQueryChanged;

  @override
  Widget build(BuildContext context) {
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
          child: _ReaderDrawerEmptyState(
            message: query.trim().isEmpty
                ? 'Bookmarks are not available yet'
                : 'No matching bookmarks',
          ),
        ),
      ],
    );
  }
}

class _ReaderSearchDrawer extends StatelessWidget {
  const _ReaderSearchDrawer({
    required this.visible,
    required this.onClose,
    required this.onSearch,
    required this.onResultSelected,
  });

  final bool visible;
  final VoidCallback onClose;
  final Future<List<ReaderSearchResult>> Function(String query) onSearch;
  final ValueChanged<ReaderSearchResult> onResultSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final drawerWidth = MediaQuery.sizeOf(context).width < 420
        ? MediaQuery.sizeOf(context).width * 0.86
        : 360.0;

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !visible,
        child: Stack(
          children: [
            AnimatedOpacity(
              opacity: visible ? 1 : 0,
              duration: _kChromeAnimDuration,
              curve: _kChromeAnimCurve,
              child: GestureDetector(
                onTap: onClose,
                behavior: HitTestBehavior.opaque,
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.28),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
            AnimatedSlide(
              offset: visible ? Offset.zero : const Offset(-1, 0),
              duration: _kChromeAnimDuration,
              curve: _kChromeAnimCurve,
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: drawerWidth,
                  child: Material(
                    color: colors.surface,
                    elevation: 0,
                    child: SafeArea(
                      right: false,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border(
                            right: BorderSide(color: colors.outlineVariant),
                          ),
                        ),
                        child: _ReaderSearchDrawerContent(
                          visible: visible,
                          onClose: onClose,
                          onSearch: onSearch,
                          onResultSelected: onResultSelected,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
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
    required this.onResultSelected,
  });

  final bool visible;
  final VoidCallback onClose;
  final Future<List<ReaderSearchResult>> Function(String query) onSearch;
  final ValueChanged<ReaderSearchResult> onResultSelected;

  @override
  State<_ReaderSearchDrawerContent> createState() =>
      _ReaderSearchDrawerContentState();
}

class _ReaderSearchDrawerContentState
    extends State<_ReaderSearchDrawerContent> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  List<ReaderSearchResult> _results = const [];
  bool _isLoading = false;
  String? _errorMessage;
  int _requestId = 0;

  @override
  void didUpdateWidget(covariant _ReaderSearchDrawerContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && !oldWidget.visible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    } else if (!widget.visible && oldWidget.visible) {
      _debounce?.cancel();
      _controller.clear();
      setState(() {
        _results = const [];
        _isLoading = false;
        _errorMessage = null;
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.length < _kBookSearchMinQueryLength) {
      _requestId++;
      setState(() {
        _results = const [];
        _isLoading = false;
        _errorMessage = null;
      });
      unawaited(widget.onSearch(''));
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _runSearch(query);
    });
  }

  Future<void> _runSearch(String query) async {
    final requestId = ++_requestId;
    try {
      final results = await widget.onSearch(query);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _results = results;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _results = const [];
        _isLoading = false;
        _errorMessage = 'Search failed';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final canSearch =
        _controller.text.trim().length >= _kBookSearchMinQueryLength;

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
        if (_isLoading) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: _ReaderDrawerContentFrame(
            child: _errorMessage != null
                ? _ReaderDrawerEmptyState(message: _errorMessage!)
                : !canSearch
                ? const _ReaderDrawerEmptyState(
                    message: 'Type at least 2 characters to search',
                  )
                : _results.isEmpty && !_isLoading
                ? const _ReaderDrawerEmptyState(message: 'No results found')
                : ScrollEdgeFadeStack(
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final result = _results[index];
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
        vertical: AppSpacing.xs,
      ),
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
                style: TextStyle(
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

    final chromeVisible = context.select<ReaderChromeCubit, bool>(
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

    final displayed = _toDisplayPage(current, total);
    final colors = context.colors;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
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
    final style = TextStyle(
      fontSize: 13,
      color: textColor,
      // Tabular figures so digit-to-digit ticks (e.g. "9 / 30" → "10
      // / 30") don't shift sub-pixel inside the reserved width.
      fontFeatures: const [FontFeature.tabularFigures()],
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
  });

  final int serverPort;
  final ReaderThemeData readerTheme;

  /// Optional GlobalKey — the parent state holds it so progress chrome can
  /// reach into [BookReaderWebViewState] for `goToFraction`.
  final GlobalKey<BookReaderWebViewState>? webViewKey;

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
  /// font/layout change in PreferencesScope, the loading-scrim flip,
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

  /// Memoization for `buildBookCustomCSS`. The CSS string only depends on
  /// the reader theme and the dark-mode image-inversion toggle; both are
  /// value-equatable, so we cache the latest pair and reuse the string
  /// across rebuilds triggered by chrome/highlight/scrim emits — those
  /// don't change either input but used to re-run the (~80-line)
  /// StringBuffer build every frame.
  String? _cachedCustomCSS;
  ReaderThemeData? _lastCssTheme;
  bool? _lastCssInvertImages;

  String _customCSSFor(ReaderThemeData theme, bool invertImagesInDark) {
    final cached = _cachedCustomCSS;
    if (cached != null &&
        _lastCssTheme == theme &&
        _lastCssInvertImages == invertImagesInDark) {
      return cached;
    }
    _lastCssTheme = theme;
    _lastCssInvertImages = invertImagesInDark;
    return _cachedCustomCSS = buildBookCustomCSS(
      theme: theme,
      invertImagesInDark: invertImagesInDark,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ReaderBloc>();
    final chromeCubit = context.read<ReaderChromeCubit>();
    final selectionCubit = context.read<ReaderSelectionCubit>();
    // Subscribe specifically to the highlights list. `state.highlights`
    // is a fresh list instance only on `ReaderHighlightsRefreshed`
    // emits — page turns and other state changes preserve the same
    // reference, so those don't trigger a rebuild.
    final highlightsState = context.select<ReaderBloc, List<Highlight>>(
      (b) => b.state.highlights,
    );
    final state = bloc.state;
    final highlights = _readerHighlightsFor(highlightsState);

    void onTapped(double x, double y) => chromeCubit.toggle();

    final appearance = PreferencesScope.readerAppearanceOf(context);
    final fontPreset = ReaderFontPreset.fromId(appearance.fontId);
    final layout = BookLayoutPreset.fromId(appearance.layoutId).data;
    final customCSS = _customCSSFor(
      widget.readerTheme,
      appearance.invertImagesInDark,
    );

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
        // Layout preset gives the baseline em-size (compact/standard/
        // comfortable); textScale is the user's per-step zoom on top
        // (slider in Profile → Font & Text Size). Multiply so both
        // controls actually take effect — earlier the slider wrote to
        // prefs but never reached the WebView.
        fontSize: layout.fontSize * appearance.textScale,
        fontWeight: layout.fontWeight,
        letterSpacing: layout.letterSpacing,
        spacing: layout.lineHeight,
        paragraphSpacing: layout.paragraphSpacing,
        textIndent: layout.textIndent,
        topMargin: layout.topMargin,
        bottomMargin: layout.bottomMargin,
        sideMargin: layout.sideMargin,
        justify: layout.justify,
        hyphenate: layout.hyphenate,
        fontColor: colorToHex(widget.readerTheme.primaryTextColor),
        backgroundColor: colorToHex(widget.readerTheme.backgroundColor),
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
          ),
        );
      },
      onTocChanged: (items) {
        bloc.add(ReaderTocUpdated(items: items));
      },
      onTextSelected: (selection) {
        chromeCubit.hide();
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
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      widget.readerTheme.primaryTextColor.withValues(
                        alpha: 0.55,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
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
      child: SafeArea(
        top: false,
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
