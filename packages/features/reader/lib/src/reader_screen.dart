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
/// from [ReaderChromeCubit] to drive the top AppBar overlay.
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

    return _ReaderTopChrome(
      visible: status != ReaderStatus.ready || chromeVisible,
      title: title,
    );
  }
}

/// Top reader chrome: AppBar overlay that slides down from the top when
/// `chromeVisible` is true. Shows only the source title for now — a
/// highlights-list action button is planned but intentionally kept out
/// until there's a real bottom sheet for it to open.
class _ReaderTopChrome extends StatelessWidget {
  const _ReaderTopChrome({required this.visible, required this.title});

  final bool visible;
  final String title;

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
            child: AppBar(
              title: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom reader chrome: progress bar. Slides up from the bottom.
class _ReaderBottomChrome extends StatelessWidget {
  const _ReaderBottomChrome({
    required this.visible,
    required this.progress,
    required this.panelColor,
    required this.textColor,
    required this.accentColor,
    required this.dividerColor,
  });

  final bool visible;
  final double progress;
  final Color panelColor;
  final Color textColor;
  final Color accentColor;
  final Color dividerColor;

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0.0, 1.0);
    final percentLabel = '${(clamped * 100).round()}%';

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedSlide(
          offset: visible ? Offset.zero : const Offset(0, 1),
          duration: _kChromeAnimDuration,
          curve: _kChromeAnimCurve,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: _kChromeAnimDuration,
            curve: _kChromeAnimCurve,
            child: Material(
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
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            value: clamped,
                            minHeight: 3,
                            backgroundColor: dividerColor,
                            valueColor: AlwaysStoppedAnimation(accentColor),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          percentLabel,
                          style: TextStyle(
                            color: textColor,
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
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

class _ReadyContentBody extends StatelessWidget {
  const _ReadyContentBody({
    required this.serverPort,
    required this.textActions,
  });

  final int serverPort;
  final List<TextAction> textActions;

  @override
  Widget build(BuildContext context) {
    final appearance = PreferencesScope.readerAppearanceOf(context);
    final readerTheme = ReaderThemePreset.fromId(appearance.themeId).data;

    return Stack(
      children: [
        // WebView body — subscribes to `state.highlights` only (via
        // context.select inside the body). Other reader state (book,
        // sourceId, theme/font/layout) is read once and stays stable
        // for the session, so non-highlight emits don't rebuild the
        // WebView. Highlight changes have to flow through so
        // BookReaderWebView.didUpdateWidget can fan them to JS.
        ColoredBox(
          color: readerTheme.backgroundColor,
          child: _ReaderWebViewBody(
            serverPort: serverPort,
            readerTheme: readerTheme,
          ),
        ),
        _BottomChromeDriver(readerTheme: readerTheme),
        _ContextPanelDriver(
          readerTheme: readerTheme,
          textActions: textActions,
        ),
        const _ReviewReminderDriver(),
      ],
    );
  }
}

/// Combines chrome visibility from [ReaderChromeCubit], selection state from
/// [ReaderSelectionCubit], and reading progress from [ReaderBloc].
class _BottomChromeDriver extends StatelessWidget {
  const _BottomChromeDriver({required this.readerTheme});

  final ReaderThemeData readerTheme;

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

    return _ReaderBottomChrome(
      visible: chromeVisible && !hasSelection,
      progress: progress,
      panelColor: readerTheme.panelColor,
      textColor: readerTheme.secondaryTextColor,
      accentColor: readerTheme.accentColor,
      dividerColor: readerTheme.dividerColor,
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
  });

  final int serverPort;
  final ReaderThemeData readerTheme;

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
    // Subscribe specifically to the highlights list so the build runs
    // when a TextAction adds/removes one. `state.highlights` is a fresh
    // list instance only on `ReaderHighlightsRefreshed` emits — page
    // turns and other state changes preserve the same reference, so
    // those don't trigger a rebuild.
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
      key: ValueKey(state.sourceId),
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
