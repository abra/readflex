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

/// Duration and curve for the top/bottom chrome slide animation.
const _kChromeAnimDuration = Duration(milliseconds: 200);
const _kChromeAnimCurve = Curves.easeOutCubic;

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
    this.onCheckDueItems,
    this.onStartMiniReview,
    super.key,
  });

  final String sourceId;
  final int serverPort;
  final BookRepository bookRepository;
  final HighlightRepository highlightRepository;
  final List<TextAction> textActions;
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
            )..add(ReaderSourceLoadRequested(sourceId: sourceId)),
          ),
          BlocProvider(create: (_) => ReaderChromeCubit()),
          BlocProvider(create: (_) => ReaderSelectionCubit()),
        ],
        child: _ReaderView(
          serverPort: serverPort,
          textActions: textActions,
        ),
      ),
    );
  }
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
          const _TopChromeDriver(),
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
      ReaderStatus.initial || ReaderStatus.loading => const Center(
        child: CircularProgressIndicator(),
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
        sourceId: context.read<ReaderBloc>().state.sourceId!,
        serverPort: serverPort,
        textActions: textActions,
      ),
    };
  }
}

/// Combines status/title/highlights from [ReaderBloc] with chrome visibility
/// from [ReaderChromeCubit] to drive the top icon-bar overlay.
class _TopChromeDriver extends StatelessWidget {
  const _TopChromeDriver();

  @override
  Widget build(BuildContext context) {
    final status = context.select<ReaderBloc, ReaderStatus>(
      (b) => b.state.status,
    );
    final title = context.select<ReaderBloc, String>((b) => b.state.title);
    final chromeVisible = context.select<ReaderChromeCubit, bool>(
      (c) => c.state.chromeVisible,
    );
    // Pull the reader theme so the top chrome panel matches the
    // page background (sepia / dark / light) rather than defaulting
    // to the app's Material surface color.
    final appearance = PreferencesScope.readerAppearanceOf(context);
    final readerTheme = ReaderThemePreset.fromId(appearance.themeId).data;

    return _ReaderTopChrome(
      visible: status != ReaderStatus.ready || chromeVisible,
      title: title,
      panelColor: readerTheme.panelColor,
      foregroundColor: readerTheme.primaryTextColor,
      dividerColor: readerTheme.dividerColor,
      onBack: () => Navigator.of(context).maybePop(),
      // Explicit nulls to silence unused-parameter analyzer warnings
      // and to document that these slots will be wired as the
      // corresponding features (TOC / font / bookmark / share)
      // land. Passing null keeps the icon greyed-out as intended.
      onTocPressed: null,
      onFontPressed: null,
      onBookmarkPressed: null,
      onSharePressed: null,
    );
  }
}

/// Top reader chrome: 5-slot icon bar (back · TOC · font · bookmark
/// · share). Slides down from the top when `chromeVisible` is true.
/// TOC / bookmark / share are placeholder slots until those features
/// land — they show as disabled icons so the layout matches the
/// design now and lights up automatically as each callback is wired
/// in [ReaderScreen].
class _ReaderTopChrome extends StatelessWidget {
  const _ReaderTopChrome({
    required this.visible,
    required this.title,
    required this.panelColor,
    required this.foregroundColor,
    required this.dividerColor,
    this.onBack,
    this.onTocPressed,
    this.onFontPressed,
    this.onBookmarkPressed,
    this.onSharePressed,
  });

  final bool visible;
  final String title;
  final Color panelColor;
  final Color foregroundColor;
  final Color dividerColor;
  final VoidCallback? onBack;
  final VoidCallback? onTocPressed;
  final VoidCallback? onFontPressed;
  final VoidCallback? onBookmarkPressed;
  final VoidCallback? onSharePressed;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedSlide(
          offset: visible ? Offset.zero : const Offset(0, -1),
          duration: _kChromeAnimDuration,
          curve: _kChromeAnimCurve,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: _kChromeAnimDuration,
            curve: _kChromeAnimCurve,
            child: DecoratedBox(
              // Shadow drops downward onto the content beneath the
              // panel. Sits outside Material so the shadow paints
              // along the panel's outer rect (hairline divider stays
              // inside as the inner separator).
              decoration: const BoxDecoration(boxShadow: AppShadows.panelDown),
              child: Material(
                color: panelColor,
                elevation: 0,
                child: SafeArea(
                  bottom: false,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: dividerColor)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                        vertical: AppSpacing.xs,
                      ),
                      child: Row(
                        children: [
                          _ReaderChromeIconButton(
                            icon: AppIcons.back,
                            tooltip: 'Back',
                            foregroundColor: foregroundColor,
                            onPressed: onBack,
                          ),
                          _ReaderChromeIconButton(
                            icon: AppIcons.toc,
                            tooltip: 'Contents',
                            foregroundColor: foregroundColor,
                            onPressed: onTocPressed,
                          ),
                          const Spacer(),
                          _ReaderChromeIconButton(
                            icon: AppIcons.font,
                            tooltip: 'Font',
                            foregroundColor: foregroundColor,
                            onPressed: onFontPressed,
                          ),
                          _ReaderChromeIconButton(
                            icon: AppIcons.bookmark,
                            tooltip: 'Bookmark',
                            foregroundColor: foregroundColor,
                            onPressed: onBookmarkPressed,
                          ),
                          _ReaderChromeIconButton(
                            icon: AppIcons.share,
                            tooltip: 'Share',
                            foregroundColor: foregroundColor,
                            onPressed: onSharePressed,
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
    );
  }
}

/// Plain icon button used in the reader's top chrome — no background,
/// no theme-injected `secondary` fill. Greys out automatically when
/// `onPressed` is null so unfinished slots read as disabled. Pulls
/// its tint from the reader theme (passed in by [_TopChromeDriver])
/// rather than the app theme so it matches the page color.
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

/// Bottom reader chrome: chapter title (left), book page number
/// (right), thin orange progress slider underneath. Slides up from
/// the bottom along with the rest of the chrome.
class _ReaderBottomChrome extends StatefulWidget {
  const _ReaderBottomChrome({
    required this.visible,
    required this.progress,
    required this.chapterTitle,
    required this.bookCurrentPage,
    required this.bookTotalPages,
    required this.panelColor,
    required this.textColor,
    required this.accentColor,
    required this.dividerColor,
    required this.onSeekFraction,
  });

  final bool visible;
  final double progress;
  final String? chapterTitle;
  final int? bookCurrentPage;
  final int? bookTotalPages;
  final Color panelColor;
  final Color textColor;
  final Color accentColor;
  final Color dividerColor;
  final ValueChanged<double> onSeekFraction;

  @override
  State<_ReaderBottomChrome> createState() => _ReaderBottomChromeState();
}

class _ReaderBottomChromeState extends State<_ReaderBottomChrome> {
  /// Local override for the slider's thumb position. Set while the
  /// user drags so the thumb tracks the finger smoothly; kept set
  /// after release until `widget.progress` catches up, so the thumb
  /// doesn't briefly snap to the pre-seek position before the
  /// post-seek `onRelocate` lands.
  double? _dragValue;

  /// True between `onChangeStart` and `onChangeEnd`. Used to gate
  /// the catchup-clear in [didUpdateWidget]: while the finger is
  /// still on the slider we keep the local override even if the
  /// bloc emits, so navigation triggered by other means doesn't
  /// fight the active drag.
  bool _isDragging = false;

  /// Hard ceiling on how long `_dragValue` can pin the slider after
  /// drag-end. The catchup-on-epsilon path in [didUpdateWidget] is
  /// fast when foliate-js lands within the epsilon of where we
  /// asked, but can miss for end-of-book snapping or when the user
  /// navigates by other means (link tap, manual page turn).
  Timer? _dragReleaseTimer;
  static const Duration _dragReleaseTimeout = Duration(milliseconds: 600);

  /// Closeness threshold for "the bloc caught up to where we
  /// dragged" — foliate-js's reported fraction can land slightly off
  /// from the requested seek (page snapping at chapter boundaries),
  /// so an exact compare would leave the slider visually stuck.
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

    // While dragging we don't actually seek — foliate-js stays on the
    // pre-drag page until release — so `widget.bookCurrentPage` is
    // stale. Show a linear `(fraction × total)` estimate during drag,
    // and the real page from the bloc when not dragging. The estimate
    // is intentionally simple: foliate-js's byte-pagination is
    // non-uniform, so even readest accepts that the drag-time number
    // is approximate.
    final dragValue = _dragValue;
    final totalPages = widget.bookTotalPages;
    final displayedPage =
        (_isDragging && dragValue != null && totalPages != null)
        ? (dragValue * totalPages).round().clamp(1, totalPages)
        : widget.bookCurrentPage;

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
              // Shadow lifts upward over the page content. Mirror of
              // the top chrome's downward shadow — same color/blur,
              // negative Y offset.
              decoration: const BoxDecoration(boxShadow: AppShadows.panelUp),
              child: Material(
                color: widget.panelColor,
                elevation: 0,
                child: SafeArea(
                  top: false,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: widget.dividerColor),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.sm,
                        AppSpacing.lg,
                        AppSpacing.xs,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
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
                                displayedPage?.toString() ?? '',
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
                          // Slider, not LinearProgressIndicator: the
                          // user can drag the thumb to seek through
                          // the book. Theme is collapsed (zero track
                          // height padding, small thumb) so it reads
                          // as a thin progress bar with a handle, not
                          // a full Material slider control.
                          SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 4,
                              activeTrackColor: widget.accentColor,
                              inactiveTrackColor: widget.dividerColor,
                              thumbColor: widget.accentColor,
                              overlayColor: widget.accentColor.withValues(
                                alpha: 0.16,
                              ),
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 7,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 16,
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
                                // No JS seek during drag. The thumb
                                // tracks the finger via `_dragValue`;
                                // foliate-js stays on the pre-drag
                                // page until release.
                                setState(() => _dragValue = v);
                              },
                              onChangeEnd: (v) {
                                // Single seek on release. `_dragValue`
                                // stays set so `didUpdateWidget` can
                                // release it once `widget.progress`
                                // catches up; `_dragReleaseTimer` is
                                // the hard ceiling for cases the
                                // bloc doesn't converge (end-of-book
                                // snap, link tap, manual page turn).
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
  /// Imperative handle on the WebView so the bottom-chrome slider can
  /// call `goToFraction(...)` directly on drag-end without bouncing
  /// through the bloc. Per-route key — the reader screen is recreated
  /// for each book open, so it's always fresh.
  final GlobalKey<BookReaderWebViewState> _webViewKey =
      GlobalKey<BookReaderWebViewState>();

  void _seekFraction(double fraction) {
    _webViewKey.currentState?.goToFraction(fraction);
  }

  @override
  Widget build(BuildContext context) {
    final appearance = PreferencesScope.readerAppearanceOf(context);
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
        _BottomChromeDriver(
          readerTheme: readerTheme,
          onSeekFraction: _seekFraction,
        ),
        _ContextPanelDriver(
          readerTheme: readerTheme,
          textActions: widget.textActions,
        ),
        const _ReviewReminderDriver(),
      ],
    );
  }
}

/// Combines chrome visibility from [ReaderChromeCubit], selection state from
/// [ReaderSelectionCubit], and reading progress from [ReaderBloc].
class _BottomChromeDriver extends StatelessWidget {
  const _BottomChromeDriver({
    required this.readerTheme,
    required this.onSeekFraction,
  });

  final ReaderThemeData readerTheme;

  /// Forwarded to the slider's drag-end handler. Skips the bloc
  /// entirely — the WebView's `goToFraction` triggers `onRelocated`
  /// once the new page lands and the bloc updates from there.
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

    return _ReaderBottomChrome(
      visible: chromeVisible && !hasSelection,
      progress: progress,
      chapterTitle: chapterTitle,
      bookCurrentPage: bookCurrentPage,
      bookTotalPages: bookTotalPages,
      panelColor: readerTheme.panelColor,
      textColor: readerTheme.secondaryTextColor,
      accentColor: readerTheme.accentColor,
      dividerColor: readerTheme.dividerColor,
      onSeekFraction: onSeekFraction,
    );
  }
}

/// Reads selection from [ReaderSelectionCubit] and source info from
/// [ReaderBloc] to show/hide the text-action context panel.
class _ContextPanelDriver extends StatelessWidget {
  const _ContextPanelDriver({
    required this.readerTheme,
    required this.textActions,
  });

  final ReaderThemeData readerTheme;
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
        panelColor: readerTheme.panelColor,
        iconColor: readerTheme.primaryTextColor,
        dividerColor: readerTheme.dividerColor,
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

class _ReaderWebViewBody extends StatefulWidget {
  const _ReaderWebViewBody({
    required this.serverPort,
    required this.readerTheme,
    this.webViewKey,
  });

  final int serverPort;
  final ReaderThemeData readerTheme;

  /// Optional GlobalKey — the parent state holds it so other chrome
  /// (the bottom-chrome slider) can reach into [BookReaderWebViewState]
  /// for imperative actions like `goToFraction`.
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
    final highlights = highlightsState
        .map(
          (h) => ReaderHighlight(
            id: h.id,
            text: h.text,
            cfiRange: h.cfiRange,
          ),
        )
        .toList();

    void onTapped(double x, double y) => chromeCubit.toggle();

    final appearance = PreferencesScope.readerAppearanceOf(context);
    final fontPreset = ReaderFontPreset.fromId(appearance.fontId);
    final layout = BookLayoutPreset.fromId(appearance.layoutId).data;
    final customCSS = buildBookCustomCSS(
      theme: widget.readerTheme,
      invertImagesInDark: appearance.invertImagesInDark,
    );

    final readerSurface = BookReaderWebView(
      // Parent's GlobalKey when provided (lets bottom chrome seek
      // imperatively). Falls back to source-id ValueKey for forced
      // remount on book change. The reader route is recreated for
      // each book open, so the key choice only matters within a
      // single session.
      key: widget.webViewKey ?? ValueKey(state.sourceId),
      serverPort: widget.serverPort,
      bookFilePath: state.book!.filePath,
      initialCfi: state.book?.currentCfi,
      foliateStyle: FoliateStyle(
        fontName: fontPreset.fontFamily,
        fontPath:
            'http://127.0.0.1:${widget.serverPort}'
            '/assets/fonts/${fontPreset.fontFile}',
        fontSize: layout.fontSize,
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
          ),
        );
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
