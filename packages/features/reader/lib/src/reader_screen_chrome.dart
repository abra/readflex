part of 'reader_screen.dart';

/// Plain icon button used in the reader action chrome — no background,
/// no theme-injected `secondary` fill. Reader controls should inherit the
/// current foreground color so they stay readable on both light and dark
/// chrome surfaces.
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
    double brightnessAfterDelta(double value, double delta) {
      return _snapReaderBrightnessButtonValue(value, delta);
    }

    void changeBrightnessBy(double delta) {
      final currentValue = cubit.state.controlValue;
      final nextValue = brightnessAfterDelta(currentValue, delta);
      debugPrint(
        '[reader-brightness] widget-button '
        'delta=${_readerBrightnessDebugValue(delta)} '
        'from=${_readerBrightnessDebugValue(currentValue)} '
        'to=${_readerBrightnessDebugValue(nextValue)} '
        'system=${_readerBrightnessDebugValue(cubit.state.systemBrightness)} '
        'override=${_readerBrightnessDebugValue(cubit.state.brightnessOverride)}',
      );
      cubit.previewBrightness(nextValue);
      cubit.commitBrightness(nextValue);
    }

    return _ReaderBrightnessChrome(
      visible: visible,
      value: controlValue,
      systemValue: brightnessState.systemBrightness,
      overrideValue: brightnessState.brightnessOverride,
      label: _readerBrightnessLabel(brightnessState),
      usesSystemBrightness: brightnessState.usesSystemBrightness,
      canIncrease:
          controlValue <
          ReaderBrightnessCubit.maxBrightness - _kReaderBrightnessEpsilon,
      canDecrease:
          controlValue >
          ReaderBrightnessCubit.minBrightness + _kReaderBrightnessEpsilon,
      onIncrease: () => changeBrightnessBy(_kReaderBrightnessStep),
      onDecrease: () => changeBrightnessBy(-_kReaderBrightnessStep),
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
    debugPrint(
      '[reader-brightness] widget-drag-end '
      'value=${_readerBrightnessDebugValue(value)} '
      'system=${_readerBrightnessDebugValue(widget.systemValue)} '
      'override=${_readerBrightnessDebugValue(widget.overrideValue)}',
    );
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
          ? 'Using system brightness: $label'
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
                child: Text(
                  label,
                  maxLines: 1,
                  style: text.labelSmall.copyWith(
                    color: active ? cs.primary : cs.onSurface,
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

/// Shows the small page-bookmark marker only when chrome/overlays are hidden.
class _ReaderPageBookmarkIndicatorDriver extends StatelessWidget {
  const _ReaderPageBookmarkIndicatorDriver();

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

/// Pulls title and chrome visibility from blocs/cubits for the top chrome bar.
class _ReaderTopChromeDriver extends StatelessWidget {
  const _ReaderTopChromeDriver({this.onArticleTitlePressed});

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
      (b) =>
          b.state.title.isNotEmpty ? b.state.title : b.state.book?.title ?? '',
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
    final colors = context.colors;

    return _ReaderTopChrome(
      visible: chromeVisible && !_selectionActionsVisible(hasSelection),
      title: title,
      onTitlePressed: onTitlePressed,
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
    this.onTitlePressed,
    required this.panelColor,
    required this.titleColor,
    required this.dividerColor,
  });

  final bool visible;
  final String title;
  final VoidCallback? onTitlePressed;
  final Color panelColor;
  final Color titleColor;
  final Color dividerColor;

  @override
  Widget build(BuildContext context) {
    final chromeAnimCurve = visible ? _kChromeAnimCurve : _kChromeHideAnimCurve;
    final baseTitleStyle = context.text.bodyMedium.copyWith(
      fontFamily: ReaderFontPreset.serif.fontFamily,
      color: titleColor,
      height: _kReaderTopChromeTitleLineHeight,
    );

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
                      horizontal: AppSpacing.md,
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final titleStyle = readerTopChromeTitleStyleForText(
                          title: title,
                          baseStyle: baseTitleStyle,
                          textDirection: Directionality.of(context),
                          maxWidth: constraints.maxWidth,
                        );
                        final titleText = Text(
                          title,
                          maxLines: _kReaderTopChromeTitleMaxLines,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: titleStyle,
                        );
                        final titleChild = onTitlePressed == null
                            ? titleText
                            : Tooltip(
                                message: 'Open original article',
                                child: Semantics(
                                  button: true,
                                  label: 'Open original article',
                                  value: title,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: onTitlePressed,
                                    child: titleText,
                                  ),
                                ),
                              );
                        return Center(child: titleChild);
                      },
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

@visibleForTesting
TextStyle readerTopChromeTitleStyleForText({
  required String title,
  required TextStyle baseStyle,
  required TextDirection textDirection,
  required double maxWidth,
}) {
  final baseFontSize = baseStyle.fontSize ?? 14.0;
  final minFontSize = _kReaderTopChromeMinTitleFontSize
      .clamp(
        0.0,
        baseFontSize,
      )
      .toDouble();

  for (
    var fontSize = baseFontSize;
    fontSize >= minFontSize;
    fontSize -= _kReaderTopChromeTitleFontStep
  ) {
    final style = baseStyle.copyWith(fontSize: fontSize);
    if (_readerTopChromeTitleFits(
      title: title,
      style: style,
      textDirection: textDirection,
      maxWidth: maxWidth,
    )) {
      return style;
    }
  }

  return baseStyle.copyWith(fontSize: minFontSize);
}

bool _readerTopChromeTitleFits({
  required String title,
  required TextStyle style,
  required TextDirection textDirection,
  required double maxWidth,
}) {
  final painter = TextPainter(
    text: TextSpan(text: title, style: style),
    textAlign: TextAlign.center,
    textDirection: textDirection,
    maxLines: _kReaderTopChromeTitleMaxLines,
    ellipsis: '...',
  )..layout(maxWidth: maxWidth);
  return !painter.didExceedMaxLines;
}

/// Combines chrome visibility from [ReaderUiCubit], selection state from
/// [ReaderSelectionCubit], and reading progress from [ReaderBloc].
class _ReaderBottomChromeDriver extends StatelessWidget {
  const _ReaderBottomChromeDriver({
    required this.onTocPressed,
    required this.onFontPressed,
    required this.onPageTurnPressed,
    required this.onBookmarkPressed,
    required this.onSearchPressed,
    required this.onSeekFraction,
  });

  final VoidCallback onTocPressed;
  final VoidCallback onFontPressed;
  final VoidCallback onPageTurnPressed;
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
          '_ReaderBottomChromeDriver build '
          'visible=${snapshot.visible} '
          'progress=${snapshot.progress.toStringAsFixed(3)} '
          'chapterPage=${snapshot.chapterCurrentPage}/'
          '${snapshot.chapterTotalPages}',
        );
        final actions = readerChromeActionsForFormat(snapshot.format);
        return _ReaderBottomChrome(
          visible: snapshot.visible,
          progress: snapshot.progress,
          chapterTitle: snapshot.chapterTitle,
          chapterCurrentPage: snapshot.chapterCurrentPage,
          chapterTotalPages: snapshot.chapterTotalPages,
          sourceType: snapshot.sourceType,
          pageProgressionRtl: snapshot.pageProgressionRtl,
          format: snapshot.format,
          panelColor: colors.surface,
          textColor: colors.onSurfaceVariant,
          accentColor: colors.primary,
          dividerColor: colors.outlineVariant,
          foregroundColor: colors.onSurface,
          bookmarkActive: snapshot.currentPageBookmarked,
          showTocAction: actions.contains(ReaderChromeAction.contents),
          showFontAction: actions.contains(ReaderChromeAction.textAppearance),
          showPageTurnAction: actions.contains(ReaderChromeAction.pageTurn),
          showBookmarkAction: actions.contains(ReaderChromeAction.bookmark),
          showSearchAction: actions.contains(ReaderChromeAction.textSearch),
          pageTurnStyle: snapshot.pageTurnStyle,
          searchActionEnabled: readerSearchActionEnabled(
            format: snapshot.format,
            documentFeatures: snapshot.documentFeatures,
          ),
          searchActionTooltip: readerSearchActionTooltip(
            format: snapshot.format,
            documentFeatures: snapshot.documentFeatures,
          ),
          onBack: () => Navigator.of(context).maybePop(),
          onTocPressed: onTocPressed,
          onFontPressed: onFontPressed,
          onPageTurnPressed: onPageTurnPressed,
          onBookmarkPressed: onBookmarkPressed,
          onSearchPressed: onSearchPressed,
          onSeekFraction: onSeekFraction,
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
    return _ReaderBottomChromeSnapshot(
      visible: visible,
      progress: state.book?.readingProgress ?? 0,
      chapterTitle: state.chapterTitle,
      chapterCurrentPage: state.chapterCurrentPage,
      chapterTotalPages: state.chapterTotalPages,
      sourceType: state.sourceType,
      pageProgressionRtl: state.pageProgressionRtl,
      format: state.book?.format,
      currentPageBookmarked: state.currentPageBookmarked,
      documentFeatures: state.documentFeatures,
      pageTurnStyle: pageTurnStyle,
    );
  }

  final bool visible;
  final double progress;
  final String? chapterTitle;
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
    required this.pageProgressionRtl,
    required this.format,
    required this.panelColor,
    required this.textColor,
    required this.accentColor,
    required this.dividerColor,
    required this.foregroundColor,
    required this.bookmarkActive,
    required this.showTocAction,
    required this.showFontAction,
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
    required this.onSeekFraction,
  });

  final bool visible;
  final double progress;
  final String? chapterTitle;
  final int? chapterCurrentPage;
  final int? chapterTotalPages;
  final SourceType sourceType;
  final bool pageProgressionRtl;
  final BookFormat? format;
  final Color panelColor;
  final Color textColor;
  final Color accentColor;
  final Color dividerColor;
  final Color foregroundColor;
  final bool bookmarkActive;
  final bool showTocAction;
  final bool showFontAction;
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
  final ValueChanged<double> onSeekFraction;

  @override
  State<_ReaderBottomChrome> createState() => _ReaderBottomChromeState();
}

class _ReaderBottomChromeState extends State<_ReaderBottomChrome> {
  /// Local override for smooth drag and for the post-release window before
  /// foliate-js reports the new snapped location back to the bloc.
  double? _dragValue;
  bool _isDragging = false;
  Timer? _dragReleaseTimer;

  static const double _dragSettleEpsilon = 0.005;
  static const double _progressSliderHeight = 30;
  static const double _progressTrackHeight = 3;
  static const double _progressThumbRadius = 6;
  static const double _progressOverlayRadius = 14;

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

  List<Widget> _buildProgressHeaderChildren({
    required TextStyle titleStyle,
    required TextStyle numberStyle,
    required String displayedText,
  }) {
    final chapterTitle = Expanded(
      child: Directionality(
        textDirection: readerChromeChapterTitleDirection(
          pageProgressionRtl: widget.pageProgressionRtl,
        ),
        child: Text(
          widget.chapterTitle ?? '',
          textAlign: readerChromeChapterTitleAlign(
            pageProgressionRtl: widget.pageProgressionRtl,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: titleStyle,
        ),
      ),
    );
    final pageIndicator = Directionality(
      textDirection: TextDirection.ltr,
      child: Text(
        displayedText,
        textAlign: TextAlign.right,
        style: numberStyle,
      ),
    );
    final children = <Widget>[];
    final slots = readerChromeProgressSlots(
      pageProgressionRtl: widget.pageProgressionRtl,
    );

    for (final slot in slots) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(width: AppSpacing.sm));
      }
      switch (slot) {
        case ReaderChromeProgressSlot.chapterTitle:
          children.add(chapterTitle);
        case ReaderChromeProgressSlot.pageIndicator:
          children.add(pageIndicator);
      }
    }

    return children;
  }

  @override
  Widget build(BuildContext context) {
    final chromeAnimCurve = widget.visible
        ? _kChromeAnimCurve
        : _kChromeHideAnimCurve;
    final displayedValue = readerSliderValue(
      sourceType: widget.sourceType,
      format: widget.format,
      progress: widget.progress,
      currentPage: widget.chapterCurrentPage,
      totalPages: widget.chapterTotalPages,
    );
    final sliderValue = snappedReaderSeekProgress(
      sourceType: widget.sourceType,
      format: widget.format,
      progress: _dragValue ?? displayedValue,
      totalPages: widget.chapterTotalPages,
    );
    final sliderDivisions = readerSliderDivisions(
      sourceType: widget.sourceType,
      format: widget.format,
      totalPages: widget.chapterTotalPages,
    );
    final showProgressSlider = shouldShowReaderProgressSlider(
      sourceType: widget.sourceType,
      format: widget.format,
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
                              textDirection: TextDirection.ltr,
                              children: _buildProgressHeaderChildren(
                                titleStyle: context.text.readerChromeLabel
                                    .copyWith(color: mutedText),
                                numberStyle: context.text.readerChromeNumber
                                    .copyWith(color: mutedText),
                                displayedText: displayedText,
                              ),
                            ),
                          ),
                          if (showProgressSlider)
                            SizedBox(
                              height: _progressSliderHeight,
                              child: SliderTheme(
                                data: SliderThemeData(
                                  trackHeight: _progressTrackHeight,
                                  activeTrackColor: widget.accentColor,
                                  inactiveTrackColor: widget.dividerColor,
                                  thumbColor: widget.accentColor,
                                  overlayColor: widget.accentColor.withValues(
                                    alpha: 0.16,
                                  ),
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: _progressThumbRadius,
                                  ),
                                  overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: _progressOverlayRadius,
                                  ),
                                  trackShape:
                                      const RoundedRectSliderTrackShape(),
                                ),
                                child: Directionality(
                                  textDirection: widget.pageProgressionRtl
                                      ? TextDirection.rtl
                                      : TextDirection.ltr,
                                  child: Slider(
                                    value: sliderValue,
                                    divisions: sliderDivisions,
                                    onChangeStart: (v) {
                                      final seekValue =
                                          snappedReaderSeekProgress(
                                            sourceType: widget.sourceType,
                                            format: widget.format,
                                            progress: v,
                                            totalPages:
                                                widget.chapterTotalPages,
                                          );
                                      setState(() {
                                        _isDragging = true;
                                        _dragValue = seekValue;
                                      });
                                    },
                                    onChanged: (v) {
                                      final seekValue =
                                          snappedReaderSeekProgress(
                                            sourceType: widget.sourceType,
                                            format: widget.format,
                                            progress: v,
                                            totalPages:
                                                widget.chapterTotalPages,
                                          );
                                      setState(() => _dragValue = seekValue);
                                    },
                                    onChangeEnd: (v) {
                                      final seekValue =
                                          snappedReaderSeekProgress(
                                            sourceType: widget.sourceType,
                                            format: widget.format,
                                            progress: v,
                                            totalPages:
                                                widget.chapterTotalPages,
                                          );
                                      widget.onSeekFraction(seekValue);
                                      _dragReleaseTimer?.cancel();
                                      _dragReleaseTimer = Timer(
                                        readerSeekSettleTimeout(
                                          format: widget.format,
                                        ),
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
                            )
                          else
                            SizedBox(
                              height: _progressSliderHeight,
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: _progressOverlayRadius,
                                  ),
                                  child: SizedBox(
                                    width: double.infinity,
                                    height: _progressTrackHeight,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: widget.accentColor,
                                        borderRadius: BorderRadius.circular(
                                          _progressTrackHeight / 2,
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

    if (widget.showPageTurnAction) {
      addButton(
        _ReaderChromeIconButton(
          icon: widget.pageTurnStyle == ReaderPageTurnStyle.vertical
              ? AppIcons.pageTurnVertical
              : AppIcons.pageTurnHorizontal,
          tooltip: widget.pageTurnStyle == ReaderPageTurnStyle.vertical
              ? 'Page turn: Vertical'
              : 'Page turn: Horizontal',
          foregroundColor: widget.accentColor,
          onPressed: widget.onPageTurnPressed,
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
          tooltip: widget.searchActionTooltip,
          foregroundColor: widget.foregroundColor,
          onPressed: widget.searchActionEnabled ? widget.onSearchPressed : null,
        ),
      );
    }

    return buttons;
  }
}

/// Feeds image-page progress metrics into the transient CBZ page overlay.
class _ReaderImagePageProgressOverlayDriver extends StatelessWidget {
  const _ReaderImagePageProgressOverlayDriver();

  @override
  Widget build(BuildContext context) {
    final format = context.select<ReaderBloc, BookFormat?>(
      (b) => b.state.book?.format,
    );
    final chromeVisible = context.select<ReaderUiCubit, bool>(
      (c) => c.state.chromeVisible,
    );
    final hasSelection = context.select<ReaderSelectionCubit, bool>(
      (c) => c.state.hasSelection,
    );
    final current = context.select<ReaderBloc, int?>(
      (b) => b.state.chapterCurrentPage,
    );
    final total = context.select<ReaderBloc, int?>(
      (b) => b.state.chapterTotalPages,
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
