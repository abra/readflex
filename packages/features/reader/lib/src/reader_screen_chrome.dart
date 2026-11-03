part of 'reader_screen.dart';

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

/// Blocks page input while reader chrome is visible.
///
/// Tap-zone logic alone is not sufficient: a swipe would still turn the page
/// under the chrome. This barrier sits above the page but below the chrome
/// panels; any pointer on the page hides chrome and is not forwarded to the
/// page.
/// Comics keep page gestures available; their edge taps also hide chrome.
class _ReaderChromeDismissBarrierDriver extends StatelessWidget {
  const _ReaderChromeDismissBarrierDriver();

  @override
  Widget build(BuildContext context) {
    final chromeOverlay = context
        .select<ReaderUiCubit, _ReaderChromeOverlaySnapshot>(
          (c) => (
            chromeVisible: c.state.chromeVisible,
            overlay: c.state.overlay,
          ),
        );
    final hasSelection = context.select<ReaderSelectionCubit, bool>(
      (c) => c.state.hasSelection,
    );
    final shouldBlockPage = shouldBlockReaderPageInput(
      isComic: context.select<ReaderBloc, bool>(
        (bloc) => bloc.state.document?.format == BookFormat.cbz,
      ),
      chromeVisible: chromeOverlay.chromeVisible,
      overlayVisible: chromeOverlay.overlay != ReaderOverlay.none,
      hasSelection: _selectionActionsVisible(hasSelection),
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
    final chromeOverlay = context
        .select<ReaderUiCubit, _ReaderChromeOverlaySnapshot>(
          (c) => (
            chromeVisible: c.state.chromeVisible,
            overlay: c.state.overlay,
          ),
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
        chromeOverlay.chromeVisible &&
        chromeOverlay.overlay == ReaderOverlay.none &&
        !_selectionActionsVisible(hasSelection);
    final controlValue = brightnessState.controlValue;
    final waitingForSystemBrightness =
        brightnessState.usesSystemBrightness &&
        brightnessState.systemBrightness == null;

    return _ReaderBrightnessChrome(
      visible: visible,
      value: controlValue,
      systemValue: brightnessState.systemBrightness,
      overrideValue: brightnessState.brightnessOverride,
      label: _readerBrightnessLabel(
        brightnessState,
        systemLabel: context.l10n.readerBrightnessSystem,
      ),
      usesSystemBrightness: brightnessState.usesSystemBrightness,
      dragEnabled: !waitingForSystemBrightness,
      canIncrease:
          waitingForSystemBrightness ||
          controlValue <
              ReaderBrightnessCubit.maxBrightness - _kReaderBrightnessEpsilon,
      canDecrease:
          waitingForSystemBrightness ||
          controlValue >
              ReaderBrightnessCubit.minBrightness + _kReaderBrightnessEpsilon,
      onIncrease: () => unawaited(
        cubit.changeBrightnessBy(_kReaderBrightnessStep),
      ),
      onDecrease: () => unawaited(
        cubit.changeBrightnessBy(-_kReaderBrightnessStep),
      ),
      onDragPreview: cubit.previewBrightness,
      onDragEnd: cubit.commitBrightness,
      onUseSystem: () => unawaited(cubit.useSystemBrightness()),
    );
  }
}

/// Inline brightness control shown beside the page while reader chrome is open.
///
/// Keeps drag preview state local so the cubit receives cheap preview updates
/// and a single persisted value on drag end.
class _ReaderBrightnessChrome extends StatefulWidget {
  const _ReaderBrightnessChrome({
    required this.visible,
    required this.value,
    required this.systemValue,
    required this.overrideValue,
    required this.label,
    required this.usesSystemBrightness,
    required this.dragEnabled,
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
  final double? systemValue;
  final double? overrideValue;
  final String label;
  final bool usesSystemBrightness;
  final bool dragEnabled;
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

  @override
  void initState() {
    super.initState();
    if (widget.visible) {
      _logWidgetBrightness('visible');
    }
  }

  @override
  void didUpdateWidget(covariant _ReaderBrightnessChrome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.visible) return;
    final becameVisible = !oldWidget.visible;
    final valueChanged =
        oldWidget.value != widget.value ||
        oldWidget.systemValue != widget.systemValue ||
        oldWidget.overrideValue != widget.overrideValue ||
        oldWidget.usesSystemBrightness != widget.usesSystemBrightness;
    if (becameVisible || valueChanged) {
      _logWidgetBrightness(becameVisible ? 'visible' : 'update');
    }
  }

  void _logWidgetBrightness(String event) {
    if (!kDebugMode) return;
    debugPrint(
      '[reader-brightness] widget-$event '
      'mode=${widget.usesSystemBrightness ? 'system' : 'custom'} '
      'widget=${_readerBrightnessDebugValue(widget.value)} '
      'system=${_readerBrightnessDebugValue(widget.systemValue)} '
      'override=${_readerBrightnessDebugValue(widget.overrideValue)} '
      'label=${widget.label}',
    );
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    if (!widget.dragEnabled) return;
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
    if (kDebugMode) {
      debugPrint(
        '[reader-brightness] widget-drag-end '
        'value=${_readerBrightnessDebugValue(value)} '
        'system=${_readerBrightnessDebugValue(widget.systemValue)} '
        'override=${_readerBrightnessDebugValue(widget.overrideValue)}',
      );
    }
    widget.onDragEnd(value);
  }

  @override
  Widget build(BuildContext context) {
    final curve = widget.visible ? _kChromeAnimCurve : _kChromeHideAnimCurve;
    final cs = context.colors;
    final borderColor = cs.outlineVariant.withValues(alpha: 0.72);
    final foreground = cs.onSurface.withValues(alpha: 0.74);
    final motion = context.motion(AppMotion.short);
    final expanded = AppWindowSize.isWide(context);
    // The pill sits at the trailing edge, so it slides out toward that edge.
    final hiddenOffset = Directionality.of(context) == TextDirection.rtl
        ? const Offset(-0.18, 0)
        : const Offset(0.18, 0);

    return PositionedDirectional(
      top: 0,
      end: expanded ? AppSpacing.sm : AppSpacing.lg,
      bottom: 0,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Center(
          child: IgnorePointer(
            key: const ValueKey('readerBrightnessChromeIgnorePointer'),
            ignoring: !widget.visible,
            child: AnimatedOpacity(
              opacity: widget.visible ? 1 : 0,
              duration: motion,
              curve: curve,
              child: AnimatedSlide(
                offset: widget.visible ? Offset.zero : hiddenOffset,
                duration: motion,
                curve: curve,
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
                    width: expanded
                        ? AppSizes.buttonHeight
                        : _kReaderBrightnessChromeWidth,
                    height: _kReaderBrightnessChromeHeight,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: expanded ? 0 : AppSpacing.xs,
                        vertical: AppSpacing.sm,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          AppPlainIconButton(
                            tooltip: context.l10n.readerIncreaseBrightness,
                            icon: AppIcons.lightMode,
                            color: foreground,
                            onPressed: widget.canIncrease
                                ? widget.onIncrease
                                : null,
                          ),
                          GestureDetector(
                            key: const ValueKey(
                              'readerBrightnessChromeDragArea',
                            ),
                            behavior: HitTestBehavior.opaque,
                            onVerticalDragUpdate: _handleVerticalDragUpdate,
                            onVerticalDragEnd: (_) => _flushDrag(),
                            onVerticalDragCancel: _flushDrag,
                            child: _ReaderBrightnessValueButton(
                              widget.label,
                              usesSystemBrightness: widget.usesSystemBrightness,
                              onPressed: widget.usesSystemBrightness
                                  ? null
                                  : widget.onUseSystem,
                            ),
                          ),
                          AppPlainIconButton(
                            tooltip: context.l10n.readerDecreaseBrightness,
                            icon: AppIcons.brightnessLow,
                            color: foreground,
                            onPressed: widget.canDecrease
                                ? widget.onDecrease
                                : null,
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

/// Current brightness value; a custom value is the selected state and tapping
/// it returns to the system level.
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
    final active = !usesSystemBrightness;
    final radius = BorderRadius.circular(AppRadius.md);

    return Semantics(
      button: true,
      enabled: onPressed != null,
      selected: active,
      label: usesSystemBrightness
          ? context.l10n.readerUsingSystemBrightness(label)
          : context.l10n.readerUseSystemBrightness,
      excludeSemantics: true,
      onTap: onPressed,
      child: Material(
        color: active ? cs.selectedControlBackground : Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onPressed,
          child: SizedBox(
            width: AppSizes.buttonHeight,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppSizes.buttonHeight,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: Center(
                  child: usesSystemBrightness
                      ? Icon(
                          AppIcons.deviceMode,
                          size: readerControlIconSize(context),
                          color: cs.onSurfaceVariant,
                        )
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            label,
                            maxLines: 1,
                            style: readerControlCaptionStyle(context).copyWith(
                              color: cs.selectedControlForeground,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.1,
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

/// Shows the small page-bookmark marker only when chrome/overlays are hidden.
@visibleForTesting
class ReaderPageBookmarkIndicatorDriver extends StatelessWidget {
  const ReaderPageBookmarkIndicatorDriver({super.key});

  @override
  Widget build(BuildContext context) {
    final chromeOverlay = context
        .select<ReaderUiCubit, _ReaderChromeOverlaySnapshot>(
          (c) => (
            chromeVisible: c.state.chromeVisible,
            overlay: c.state.overlay,
          ),
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
    final visible =
        bookmarked &&
        !chromeOverlay.chromeVisible &&
        chromeOverlay.overlay == ReaderOverlay.none &&
        !_selectionActionsVisible(hasSelection);
    final topOffset =
        BookLayoutPreset.fromId(layoutId).data.topMargin -
        _kReaderPageBookmarkIndicatorLift;

    return _ReaderPageBookmarkIndicator(
      visible: visible,
      color: context.actionForeground,
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

    return PositionedDirectional(
      top: topOffset,
      end: AppSpacing.lg,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: context.motion(AppMotion.short),
          curve: curve,
          child: Semantics(
            label: context.l10n.readerPageBookmarked,
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

/// Height of the top line and of the article-title tap target.
const _kReaderTopChromeLineHeight = AppSizes.buttonHeight;

/// Fade between the page and the page-coloured band under chrome text, so
/// scrolled text never runs behind a label.
const _kReaderChromeBackdropFade = AppSpacing.lg;

const _kReaderActionStripHeight = 60.0;

/// Keeps the reading dock compact on landscape phones and tablets.
const _kReaderBottomChromeMaxWidth = 560.0;

/// Progress has a little more inset than the action targets below it.
const _kReaderProgressRowInset = AppSpacing.md;
const _kReaderProgressTrackHeight = 3.0;

/// Keeps article progress visible below the title, or at the safe top edge
/// when the title is hidden. Position updates rebuild only this indicator.
@visibleForTesting
class ReaderArticleProgressDriver extends StatelessWidget {
  const ReaderArticleProgressDriver({required this.readerTheme, super.key});

  final ReaderThemeData readerTheme;

  @override
  Widget build(BuildContext context) {
    final document = context.select<ReaderBloc, (bool, bool)>(
      (b) => (
        b.state.sourceType == SourceType.article,
        b.state.pageProgressionRtl,
      ),
    );
    if (!document.$1) return const SizedBox.shrink();
    final progress = context.select<ReaderArticleProgressCubit, double?>(
      (c) => c.state,
    );
    if (progress == null) return const SizedBox.shrink();
    final chromeVisible = context.select<ReaderUiCubit, bool>(
      (c) => c.state.chromeVisible,
    );
    final hasSelection = context.select<ReaderSelectionCubit, bool>(
      (c) => c.state.hasSelection,
    );
    final titleVisible = chromeVisible && !hasSelection;
    final padding = MediaQuery.paddingOf(context);

    return AnimatedPositioned(
      left: padding.left,
      right: padding.right,
      top: padding.top + (titleVisible ? _kReaderTopChromeLineHeight : 0),
      duration: context.motion(AppMotion.short),
      curve: titleVisible ? _kChromeAnimCurve : _kChromeHideAnimCurve,
      child: IgnorePointer(
        child: Directionality(
          textDirection: document.$2 ? TextDirection.rtl : TextDirection.ltr,
          child: LinearProgressIndicator(
            key: const ValueKey('readerArticleProgress'),
            value: progress,
            minHeight: _kReaderProgressTrackHeight,
            color: readerChromeInkColor(readerTheme),
            backgroundColor: readerChromeTrackColor(readerTheme),
            borderRadius: BorderRadius.zero,
            stopIndicatorRadius: 0,
            trackGap: 0,
            semanticsLabel: context.l10n.librarySourcePercentRead(
              (progress * 100).round(),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pulls title, chapter and chrome visibility for the top chrome line.
@visibleForTesting
class ReaderTopChromeDriver extends StatelessWidget {
  const ReaderTopChromeDriver({
    required this.readerTheme,
    this.onArticleTitlePressed,
    super.key,
  });

  final ReaderThemeData readerTheme;
  final void Function(String url, String title)? onArticleTitlePressed;

  @override
  Widget build(BuildContext context) {
    final chromeVisible = context.select<ReaderUiCubit, bool>(
      (c) => c.state.chromeVisible,
    );
    final hasSelection = context.select<ReaderSelectionCubit, bool>(
      (c) => c.state.hasSelection,
    );
    final title = context.select<ReaderBloc, String>(
      (b) => b.state.title.isNotEmpty
          ? b.state.title
          : b.state.document?.title ?? '',
    );
    // Comic "chapters" are archive file names.
    final chapterTitle = context.select<ReaderBloc, String?>(
      (b) => isImagePageFormat(b.state.document?.format)
          ? null
          : b.state.chapterTitle,
    );
    final articleUrl = context.select<ReaderBloc, String?>(
      (b) =>
          b.state.sourceType == SourceType.article ? b.state.articleUrl : null,
    );
    final trimmedArticleUrl = articleUrl?.trim() ?? '';
    final onTitlePressed =
        onArticleTitlePressed != null &&
            trimmedArticleUrl.isNotEmpty &&
            title.trim().isNotEmpty
        ? () => onArticleTitlePressed!(trimmedArticleUrl, title)
        : null;

    return _ReaderTopChrome(
      visible: chromeVisible && !_selectionActionsVisible(hasSelection),
      line: readerTopChromeLine(title: title, chapterTitle: chapterTitle),
      title: title,
      onTitlePressed: onTitlePressed,
      textColor: readerChromeInkColor(readerTheme),
      pageColor: readerTheme.backgroundColor,
    );
  }
}

/// A single muted line on the page: no panel, shadow or divider. A
/// page-coloured band behind it keeps scrolled text from running under it.
class _ReaderTopChrome extends StatelessWidget {
  const _ReaderTopChrome({
    required this.visible,
    required this.line,
    required this.title,
    required this.textColor,
    required this.pageColor,
    this.onTitlePressed,
  });

  final bool visible;
  final String line;
  final String title;
  final Color textColor;
  final Color pageColor;
  final VoidCallback? onTitlePressed;

  @override
  Widget build(BuildContext context) {
    final chromeAnimCurve = visible ? _kChromeAnimCurve : _kChromeHideAnimCurve;
    final motion = context.motion(AppMotion.short);
    final lineText = Text(
      line,
      key: const ValueKey('readerTopChromeLine'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: readerChromeLabelStyle(context).copyWith(color: textColor),
    );

    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedSlide(
          offset: visible ? Offset.zero : const Offset(0, -1),
          duration: motion,
          curve: chromeAnimCurve,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: motion,
            curve: chromeAnimCurve,
            child: Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: _ReaderPageBackdrop(
                      color: pageColor,
                      fadeAtTop: false,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    bottom: _kReaderChromeBackdropFade,
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: SizedBox(
                      height: _kReaderTopChromeLineHeight,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                        ),
                        child: Center(
                          child: onTitlePressed == null
                              ? lineText
                              : _ReaderArticleTitleButton(
                                  title: title,
                                  onPressed: onTitlePressed!,
                                  child: lineText,
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Page colour behind chrome text, fading out toward the page.
class _ReaderPageBackdrop extends StatelessWidget {
  const _ReaderPageBackdrop({required this.color, required this.fadeAtTop});

  final Color color;
  final bool fadeAtTop;

  @override
  Widget build(BuildContext context) {
    final fade = SizedBox(
      height: _kReaderChromeBackdropFade,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: fadeAtTop ? Alignment.topCenter : Alignment.bottomCenter,
            end: fadeAtTop ? Alignment.bottomCenter : Alignment.topCenter,
            colors: [color.withValues(alpha: 0), color],
          ),
        ),
      ),
    );
    final band = Expanded(child: ColoredBox(color: color));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: fadeAtTop ? [fade, band] : [band, fade],
    );
  }
}

/// Article title that opens the original URL. Keeps the line's text size and
/// adds a full-height ink target with button semantics.
class _ReaderArticleTitleButton extends StatelessWidget {
  const _ReaderArticleTitleButton({
    required this.title,
    required this.onPressed,
    required this.child,
  });

  final String title;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.readerOpenOriginalArticle;
    final radius = BorderRadius.circular(AppRadius.sm);
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        enabled: true,
        label: label,
        value: title,
        excludeSemantics: true,
        onTap: onPressed,
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          child: InkWell(
            key: const ValueKey('readerArticleTitleButton'),
            borderRadius: radius,
            onTap: onPressed,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppSizes.buttonHeight,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                ),
                child: Center(widthFactor: 1, child: child),
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
@visibleForTesting
class ReaderBottomChromeDriver extends StatelessWidget {
  const ReaderBottomChromeDriver({
    required this.readerTheme,
    required this.onTocPressed,
    required this.onFontPressed,
    required this.onPageTurnPressed,
    required this.onBookmarkPressed,
    required this.onSearchPressed,
    required this.onSeekFraction,
    super.key,
  });

  final ReaderThemeData readerTheme;
  final VoidCallback onTocPressed;
  final VoidCallback onFontPressed;

  /// Comic page-turn axis toggle. Comics have no Appearance action, so this
  /// is their only route to the setting.
  final VoidCallback onPageTurnPressed;
  final VoidCallback onBookmarkPressed;
  final VoidCallback onSearchPressed;

  /// Forwarded to the slider's drag-end handler. Skips the bloc entirely —
  /// the surface's `goToFraction` reports the new position once the page
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
    final visible = chromeVisible && !_selectionActionsVisible(hasSelection);
    final pageTurnStyle = context
        .select<ReaderAppearanceCubit, ReaderPageTurnStyle>(
          (c) => c.state.effectiveAppearance.pageTurnStyle,
        );
    final colors = context.colors;

    return BlocSelector<ReaderBloc, ReaderState, _ReaderBottomChromeSnapshot>(
      selector: (state) => _ReaderBottomChromeSnapshot.fromState(
        state,
        visible: visible,
        pageTurnStyle: pageTurnStyle,
      ),
      builder: (context, snapshot) {
        _debugTraceReader(
          'ReaderBottomChromeDriver build '
          'visible=${snapshot.visible} '
          'progress=${snapshot.progress.toStringAsFixed(3)} '
          'chapterPage=${snapshot.chapterCurrentPage}/'
          '${snapshot.chapterTotalPages} '
          'minutesLeft=${snapshot.minutesLeft}',
        );
        final l10n = context.l10n;
        final actions = readerChromeActionsFor(
          sourceType: snapshot.sourceType,
          format: snapshot.format,
        );
        // Books name the current chapter; articles have none to name, so
        // they show the time left in the whole article.
        final timeLeft = snapshot.sourceType == SourceType.article
            ? readerChromeArticleTimeLeftLabel(
                l10n,
                minutes: snapshot.minutesLeft,
              )
            : null;
        return _ReaderBottomChrome(
          visible: snapshot.visible,
          progress: _ReaderProgressRow(
            progress: snapshot.progress,
            startLabel: timeLeft ?? snapshot.chapterTitle ?? '',
            startLabelIsUiCopy: timeLeft != null,
            chapterCurrentPage: snapshot.chapterCurrentPage,
            chapterTotalPages: snapshot.chapterTotalPages,
            sourceType: snapshot.sourceType,
            pageProgressionRtl: snapshot.pageProgressionRtl,
            format: snapshot.format,
            inkColor: colors.onSurfaceVariant,
            trackColor: colors.outlineVariant,
            formatPageOfTotal: l10n.readerPageOfTotal,
            onSeekFraction: onSeekFraction,
          ),
          actions: _ReaderChromeActionStrip(
            foregroundColor: colors.onSurface,
            actionColor: context.actionForeground,
            bookmarkActive: snapshot.currentPageBookmarked,
            showTocAction: actions.contains(ReaderChromeAction.contents),
            showFontAction: actions.contains(ReaderChromeAction.textAppearance),
            // PDF pages have no font: the sheet holds page appearance.
            fontActionTooltip: snapshot.format == BookFormat.pdf
                ? l10n.readerAppearanceTitle
                : l10n.readerFontAction,
            showPageTurnAction: actions.contains(ReaderChromeAction.pageTurn),
            showBookmarkAction: actions.contains(ReaderChromeAction.bookmark),
            showSearchAction: actions.contains(ReaderChromeAction.textSearch),
            pageTurnStyle: snapshot.pageTurnStyle,
            searchActionEnabled: readerSearchActionEnabled(
              format: snapshot.format,
              documentFeatures: snapshot.documentFeatures,
            ),
            searchActionTooltip: readerSearchActionTooltip(
              l10n: l10n,
              format: snapshot.format,
              documentFeatures: snapshot.documentFeatures,
            ),
            onBack: () => Navigator.of(context).maybePop(),
            onTocPressed: onTocPressed,
            onFontPressed: onFontPressed,
            onPageTurnPressed: onPageTurnPressed,
            onBookmarkPressed: onBookmarkPressed,
            onSearchPressed: onSearchPressed,
          ),
        );
      },
    );
  }
}

/// Equality-optimized reader state slice used by [BlocSelector].
///
/// When the chrome is hidden, all visible-content fields are ignored so page
/// boundary updates do not rebuild the bottom chrome subtree.
class _ReaderBottomChromeSnapshot {
  const _ReaderBottomChromeSnapshot({
    required this.visible,
    required this.progress,
    required this.chapterTitle,
    required this.minutesLeft,
    required this.chapterCurrentPage,
    required this.chapterTotalPages,
    required this.sourceType,
    required this.pageProgressionRtl,
    required this.format,
    required this.currentPageBookmarked,
    required this.documentFeatures,
    required this.pageTurnStyle,
  });

  factory _ReaderBottomChromeSnapshot.fromState(
    ReaderState state, {
    required bool visible,
    required ReaderPageTurnStyle pageTurnStyle,
  }) {
    final format = state.document?.format;
    // Comic "chapters" are archive file names and their section estimate is
    // image bytes; only the page counter is meaningful there.
    final imagePages = isImagePageFormat(format);
    return _ReaderBottomChromeSnapshot(
      visible: visible,
      progress: state.document?.readingProgress ?? 0,
      chapterTitle: imagePages ? null : state.chapterTitle,
      minutesLeft: imagePages ? null : state.minutesLeft,
      chapterCurrentPage: state.chapterCurrentPage,
      chapterTotalPages: state.chapterTotalPages,
      sourceType: state.sourceType,
      pageProgressionRtl: state.pageProgressionRtl,
      format: format,
      currentPageBookmarked: state.currentPageBookmarked,
      documentFeatures: state.documentFeatures,
      pageTurnStyle: pageTurnStyle,
    );
  }

  final bool visible;
  final double progress;
  final String? chapterTitle;
  final double? minutesLeft;
  final int? chapterCurrentPage;
  final int? chapterTotalPages;
  final SourceType sourceType;
  final bool pageProgressionRtl;
  final BookFormat? format;
  final bool currentPageBookmarked;
  final ReaderDocumentFeatures? documentFeatures;
  final ReaderPageTurnStyle pageTurnStyle;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! _ReaderBottomChromeSnapshot) return false;
    if (visible != other.visible) return false;
    if (!visible) return true;
    return progress == other.progress &&
        chapterTitle == other.chapterTitle &&
        minutesLeft == other.minutesLeft &&
        chapterCurrentPage == other.chapterCurrentPage &&
        chapterTotalPages == other.chapterTotalPages &&
        sourceType == other.sourceType &&
        pageProgressionRtl == other.pageProgressionRtl &&
        format == other.format &&
        currentPageBookmarked == other.currentPageBookmarked &&
        documentFeatures == other.documentFeatures &&
        pageTurnStyle == other.pageTurnStyle;
  }

  @override
  int get hashCode {
    if (!visible) return visible.hashCode;
    return Object.hash(
      visible,
      progress,
      chapterTitle,
      minutesLeft,
      chapterCurrentPage,
      chapterTotalPages,
      sourceType,
      pageProgressionRtl,
      format,
      currentPageBookmarked,
      documentFeatures,
      pageTurnStyle,
    );
  }
}

/// One floating reading dock, keeping status, seeking and actions together.
class _ReaderBottomChrome extends StatelessWidget {
  const _ReaderBottomChrome({
    required this.visible,
    required this.progress,
    required this.actions,
  });

  final bool visible;
  final Widget progress;
  final Widget actions;

  @override
  Widget build(BuildContext context) {
    final chromeAnimCurve = visible ? _kChromeAnimCurve : _kChromeHideAnimCurve;
    final motion = context.motion(AppMotion.short);

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedSlide(
          offset: visible ? Offset.zero : const Offset(0, 1),
          duration: motion,
          curve: chromeAnimCurve,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: motion,
            curve: chromeAnimCurve,
            child: SafeArea(
              top: false,
              bottom: false,
              child: Center(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: _kReaderBottomChromeMaxWidth,
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      appBottomSafeInset(context),
                    ),
                    child: ToastAvoidArea(
                      enabled: visible,
                      child: _ReaderChromeDock(
                        progress: progress,
                        actions: actions,
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

class _ReaderChromeDock extends StatelessWidget {
  const _ReaderChromeDock({required this.progress, required this.actions});

  final Widget progress;
  final Widget actions;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(AppRadius.xl);
    return DecoratedBox(
      key: const ValueKey('readerChromeDock'),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: radius,
        border: Border.all(
          color: colors.outlineVariant,
          width: 1 / MediaQuery.devicePixelRatioOf(context),
        ),
        boxShadow: AppShadows.popover,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                _kReaderProgressRowInset,
                AppSpacing.md,
                _kReaderProgressRowInset,
                AppSpacing.sm,
              ),
              child: progress,
            ),
            actions,
          ],
        ),
      ),
    );
  }
}

/// Equal 48dp action targets, with captions when a wide window has room.
class _ReaderChromeActionStrip extends StatelessWidget {
  const _ReaderChromeActionStrip({
    required this.foregroundColor,
    required this.actionColor,
    required this.bookmarkActive,
    required this.showTocAction,
    required this.showFontAction,
    required this.fontActionTooltip,
    required this.showPageTurnAction,
    required this.showBookmarkAction,
    required this.showSearchAction,
    required this.pageTurnStyle,
    required this.searchActionEnabled,
    required this.searchActionTooltip,
    this.onBack,
    this.onTocPressed,
    this.onFontPressed,
    this.onPageTurnPressed,
    this.onBookmarkPressed,
    this.onSearchPressed,
  });

  final Color foregroundColor;
  final Color actionColor;
  final bool bookmarkActive;
  final bool showTocAction;
  final bool showFontAction;
  final String fontActionTooltip;
  final bool showPageTurnAction;
  final bool showBookmarkAction;
  final bool showSearchAction;
  final ReaderPageTurnStyle pageTurnStyle;
  final bool searchActionEnabled;
  final String searchActionTooltip;
  final VoidCallback? onBack;
  final VoidCallback? onTocPressed;
  final VoidCallback? onFontPressed;
  final VoidCallback? onPageTurnPressed;
  final VoidCallback? onBookmarkPressed;
  final VoidCallback? onSearchPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final verticalPageTurn = pageTurnStyle == ReaderPageTurnStyle.vertical;
    final bookmarkColor = bookmarkActive ? actionColor : foregroundColor;
    final slots = <_ReaderChromeActionData>[
      _ReaderChromeActionData(
        label: l10n.readerBack,
        icon: AppIcons.back,
        iconSize: AppIconSize.lg,
        tooltip: l10n.readerBack,
        color: foregroundColor,
        onPressed: onBack,
      ),
      if (showTocAction)
        _ReaderChromeActionData(
          label: l10n.readerContents,
          icon: AppIcons.toc,
          tooltip: l10n.readerContents,
          color: foregroundColor,
          onPressed: onTocPressed,
        ),
      if (showFontAction)
        _ReaderChromeActionData(
          label: l10n.readerAppearanceTitle,
          icon: AppIcons.font,
          tooltip: fontActionTooltip,
          color: foregroundColor,
          onPressed: onFontPressed,
        ),
      if (showPageTurnAction)
        _ReaderChromeActionData(
          label: verticalPageTurn
              ? l10n.readerPageTurnVerticalShort
              : l10n.readerPageTurnHorizontalShort,
          icon: verticalPageTurn
              ? AppIcons.pageTurnVertical
              : AppIcons.pageTurnHorizontal,
          tooltip: verticalPageTurn
              ? l10n.readerPageTurnVertical
              : l10n.readerPageTurnHorizontal,
          color: actionColor,
          onPressed: onPageTurnPressed,
        ),
      if (showBookmarkAction)
        _ReaderChromeActionData(
          label: l10n.readerBookmark,
          glyph: _ReaderBookmarkGlyph(
            filled: bookmarkActive,
            color: onBookmarkPressed == null
                ? bookmarkColor.withValues(alpha: 0.38)
                : bookmarkColor,
            size: AppIconSize.md,
          ),
          tooltip: bookmarkActive
              ? l10n.readerRemoveBookmark
              : l10n.readerBookmark,
          color: bookmarkColor,
          onPressed: onBookmarkPressed,
        ),
      if (showSearchAction)
        _ReaderChromeActionData(
          label: l10n.readerSearchAction,
          icon: AppIcons.search,
          tooltip: searchActionTooltip,
          color: foregroundColor,
          onPressed: searchActionEnabled ? onSearchPressed : null,
        ),
    ];
    final labelStyle = readerControlCaptionStyle(context);
    final scaledLabelSize = MediaQuery.textScalerOf(
      context,
    ).scale(labelStyle.fontSize!);
    final showLabels =
        AppWindowSize.isWide(context) &&
        scaledLabelSize <= labelStyle.fontSize! * 1.3;
    final largestIcon = slots.fold(
      0.0,
      (size, action) => math.max(size, action.iconSize),
    );
    // Two translated lines keep their scaled height; 80dp is only a minimum.
    final labeledHeight = math.max(
      AppSizes.buttonHeight + AppSpacing.xl + AppSpacing.sm,
      largestIcon +
          AppSpacing.xs +
          scaledLabelSize * labelStyle.height! * 2 +
          AppSpacing.xs * 2,
    );
    return SizedBox(
      key: const ValueKey('readerChromeCapsule'),
      height: showLabels ? labeledHeight : _kReaderActionStripHeight,
      child: Row(
        children: [
          for (final action in slots)
            Expanded(
              child: _ReaderChromeAction(
                action: action,
                showLabel: showLabels,
              ),
            ),
        ],
      ),
    );
  }
}

@immutable
class _ReaderChromeActionData {
  const _ReaderChromeActionData({
    required this.label,
    required this.tooltip,
    required this.color,
    required this.onPressed,
    this.icon,
    this.glyph,
    this.iconSize = AppIconSize.md,
  }) : assert((icon == null) != (glyph == null));

  final String label;
  final String tooltip;
  final Color color;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Widget? glyph;
  final double iconSize;
}

class _ReaderChromeAction extends StatelessWidget {
  const _ReaderChromeAction({
    required this.action,
    required this.showLabel,
  });

  final _ReaderChromeActionData action;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    if (!showLabel) {
      return Center(
        child: AppPlainIconButton(
          icon: action.icon,
          iconWidget: action.glyph,
          iconSize: action.iconSize,
          tooltip: action.tooltip,
          color: action.color,
          onPressed: action.onPressed,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xs),
      child: Tooltip(
        message: action.tooltip,
        child: TextButton(
          onPressed: action.onPressed,
          style: TextButton.styleFrom(
            foregroundColor: action.color,
            disabledForegroundColor: action.color.withValues(alpha: 0.38),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
          ),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                action.glyph ?? Icon(action.icon, size: action.iconSize),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  action.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: readerControlCaptionStyle(context).copyWith(
                    color: action.onPressed == null
                        ? action.color.withValues(alpha: 0.38)
                        : action.color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Time left (or chapter), the thin progress slider and the page label.
///
/// It intentionally keeps seek state local: dragging the thumb rebuilds only
/// this row and does not move the page on every tick; only `onChangeEnd`
/// calls `goToFraction(...)`.
class _ReaderProgressRow extends StatefulWidget {
  const _ReaderProgressRow({
    required this.progress,
    required this.startLabel,
    required this.startLabelIsUiCopy,
    required this.chapterCurrentPage,
    required this.chapterTotalPages,
    required this.sourceType,
    required this.pageProgressionRtl,
    required this.format,
    required this.inkColor,
    required this.trackColor,
    required this.formatPageOfTotal,
    required this.onSeekFraction,
  });

  final double progress;

  /// Time left, else the chapter title, else empty (comics).
  final String startLabel;

  /// Time left is app copy in the UI direction; a chapter title follows the
  /// book.
  final bool startLabelIsUiCopy;
  final int? chapterCurrentPage;
  final int? chapterTotalPages;
  final SourceType sourceType;
  final bool pageProgressionRtl;
  final BookFormat? format;
  final Color inkColor;
  final Color trackColor;
  final String Function(int page, int total) formatPageOfTotal;
  final ValueChanged<double> onSeekFraction;

  @override
  State<_ReaderProgressRow> createState() => _ReaderProgressRowState();
}

class _ReaderProgressRowState extends State<_ReaderProgressRow> {
  /// Local override for smooth drag and for the post-release window before
  /// the surface reports the new snapped location back to the bloc.
  double? _dragValue;
  bool _isDragging = false;
  Timer? _dragReleaseTimer;

  static const double _dragSettleEpsilon = 0.005;
  static const double _progressThumbRadius = 6;

  @override
  void dispose() {
    _dragReleaseTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(_ReaderProgressRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isDragging) return;
    final dragValue = _dragValue;
    if (dragValue == null) return;
    final displayedValue = readerSliderValue(
      sourceType: widget.sourceType,
      format: widget.format,
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

  double _seekValue(double value) => snappedReaderSeekProgress(
    sourceType: widget.sourceType,
    format: widget.format,
    progress: value,
    totalPages: widget.chapterTotalPages,
  );

  void _handleChangeStart(double value) {
    final seekValue = _seekValue(value);
    setState(() {
      _isDragging = true;
      _dragValue = seekValue;
    });
  }

  void _handleChanged(double value) {
    final seekValue = _seekValue(value);
    setState(() => _dragValue = seekValue);
  }

  void _handleChangeEnd(double value) {
    final seekValue = _seekValue(value);
    widget.onSeekFraction(seekValue);
    _dragReleaseTimer?.cancel();
    _dragReleaseTimer = Timer(
      readerSeekSettleTimeout(format: widget.format),
      () {
        if (!mounted) return;
        _dragReleaseTimer = null;
        if (_dragValue != null) setState(() => _dragValue = null);
      },
    );
    setState(() {
      _isDragging = false;
      _dragValue = seekValue;
    });
  }

  @override
  Widget build(BuildContext context) {
    final displayedValue = readerSliderValue(
      sourceType: widget.sourceType,
      format: widget.format,
      progress: widget.progress,
      currentPage: widget.chapterCurrentPage,
      totalPages: widget.chapterTotalPages,
    );
    final sliderValue = _seekValue(_dragValue ?? displayedValue);
    final showProgressSlider = shouldShowReaderProgressSlider(
      sourceType: widget.sourceType,
      format: widget.format,
      totalPages: widget.chapterTotalPages,
    );
    final pageLabel = readerProgressLabel(
      sourceType: widget.sourceType,
      format: widget.format,
      progress: sliderValue,
      chapterCurrentPage: widget.chapterCurrentPage,
      chapterTotalPages: widget.chapterTotalPages,
      isDragging: _dragValue != null,
      formatPageOfTotal: widget.formatPageOfTotal,
    );
    final uiDirection = Directionality.of(context);
    // The row follows the book's page progression, like the slider itself.
    final progressionDirection = widget.pageProgressionRtl
        ? TextDirection.rtl
        : TextDirection.ltr;
    final labelStyle = readerChromeLabelStyle(context);
    final numberStyle = readerChromeNumberStyle(context);
    final progressTrack = showProgressSlider
        ? SliderTheme(
            data: SliderThemeData(
              trackHeight: _kReaderProgressTrackHeight,
              activeTrackColor: widget.inkColor,
              inactiveTrackColor: widget.trackColor,
              thumbColor: widget.inkColor,
              overlayColor: widget.inkColor.withValues(alpha: 0.12),
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: _progressThumbRadius,
              ),
              overlayShape: const RoundSliderOverlayShape(
                overlayRadius: readerProgressTrackInset,
              ),
              trackShape: const RoundedRectSliderTrackShape(),
            ),
            child: Slider(
              value: sliderValue,
              divisions: readerSliderDivisions(
                sourceType: widget.sourceType,
                format: widget.format,
                totalPages: widget.chapterTotalPages,
              ),
              onChangeStart: _handleChangeStart,
              onChanged: _handleChanged,
              onChangeEnd: _handleChangeEnd,
            ),
          )
        : Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: readerProgressTrackInset,
            ),
            child: Center(
              child: SizedBox(
                width: double.infinity,
                height: _kReaderProgressTrackHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: widget.inkColor,
                    borderRadius: BorderRadius.circular(
                      _kReaderProgressTrackHeight / 2,
                    ),
                  ),
                ),
              ),
            ),
          );

    final stacked = readerProgressLabelsStack(
      MediaQuery.textScalerOf(context),
      fontSize: labelStyle.fontSize!,
    );
    final startText = widget.startLabel.isEmpty
        ? null
        : Text(
            widget.startLabel,
            key: const ValueKey('readerProgressStartLabel'),
            textDirection: widget.startLabelIsUiCopy
                ? uiDirection
                : progressionDirection,
            maxLines: stacked ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: labelStyle.copyWith(color: widget.inkColor),
          );
    final pageText = Text(
      pageLabel,
      key: const ValueKey('readerProgressPageLabel'),
      textDirection: TextDirection.ltr,
      textAlign: widget.pageProgressionRtl ? TextAlign.left : TextAlign.right,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: numberStyle.copyWith(color: widget.inkColor),
    );

    // Read status first, then seek, then reach the actions below it.
    return Directionality(
      textDirection: progressionDirection,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: readerProgressTrackInset,
            ),
            child: _ReaderProgressLabels(
              start: startText,
              page: pageText,
              stacked: stacked,
            ),
          ),
          SizedBox(height: AppSizes.buttonHeight, child: progressTrack),
        ],
      ),
    );
  }
}

/// Status above the slider: the chapter (or time left) at the start, the
/// page label at the end. With large text each takes its own line.
class _ReaderProgressLabels extends StatelessWidget {
  const _ReaderProgressLabels({
    required this.start,
    required this.page,
    required this.stacked,
  });

  final Widget? start;
  final Widget page;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final start = this.start;
    if (stacked) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ?start,
          Align(alignment: AlignmentDirectional.centerEnd, child: page),
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: start ?? const SizedBox.shrink()),
          const SizedBox(width: readerProgressLabelGap),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: readerProgressEndLabelMaxWidth(constraints.maxWidth),
            ),
            child: page,
          ),
        ],
      ),
    );
  }
}

/// Feeds image-page progress metrics into the transient CBZ page overlay.
class _ReaderImagePageProgressOverlayDriver extends StatelessWidget {
  const _ReaderImagePageProgressOverlayDriver();

  @override
  Widget build(BuildContext context) {
    final format = context.select<ReaderBloc, BookFormat?>(
      (b) => b.state.document?.format,
    );
    final chromeVisible = context.select<ReaderUiCubit, bool>(
      (c) => c.state.chromeVisible,
    );
    final hasSelection = context.select<ReaderSelectionCubit, bool>(
      (c) => c.state.hasSelection,
    );
    // Text pages change these on every turn, for a pill they never show.
    final imagePages = isImagePageFormat(format);
    final current = context.select<ReaderBloc, int?>(
      (b) => imagePages ? b.state.chapterCurrentPage : null,
    );
    final total = context.select<ReaderBloc, int?>(
      (b) => imagePages ? b.state.chapterTotalPages : null,
    );

    return ReaderImagePageProgressOverlay(
      format: format,
      chromeVisible: chromeVisible,
      selectionActionsVisible: _selectionActionsVisible(hasSelection),
      currentPage: current,
      totalPages: total,
    );
  }
}
