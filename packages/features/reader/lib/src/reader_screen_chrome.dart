import 'dart:async';
import 'dart:math' as math;

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:toast_service/toast_service.dart';

import 'reader_appearance_cubit.dart';
import 'reader_article_progress_cubit.dart';
import 'reader_bloc.dart';
import 'reader_brightness_cubit.dart';
import 'reader_chrome_action_button.dart';
import 'reader_chrome_actions.dart';
import 'reader_chrome_colors.dart';
import 'reader_chrome_labels.dart';
import 'reader_chrome_progress_layout.dart';
import 'reader_control_styles.dart';
import 'reader_diagnostics.dart';
import 'reader_document_features.dart';
import 'reader_drawer_messages.dart';
import 'reader_floating_chrome_layout.dart';
import 'reader_image_page_progress_overlay.dart';
import 'reader_progress_label.dart';
import 'reader_screen_cupertino_actions.dart';
import 'reader_selection_cubit.dart';
import 'reader_tap_action.dart';
import 'reader_ui_cubit.dart';

/// Curves for the reader chrome slide animation; durations come from
/// `context.motion(AppMotion.short)` so reduced motion settles in one frame.
const _kChromeAnimCurve = Curves.easeOutCubic;
const _kChromeHideAnimCurve = Curves.easeInCubic;
const _kReaderPageBookmarkIndicatorLift = 28.0;
const _kReaderPageBookmarkIndicatorSize = AppIconSize.md;
const _kReaderBrightnessStep = 0.05;
const _kReaderBrightnessEpsilon = 0.0001;
// Three 48dp controls stacked inside the pill's horizontal/vertical padding.
const _kReaderBrightnessChromeWidth = AppSizes.buttonHeight + AppSpacing.xs * 2;
const _kReaderBrightnessChromeHeight = readerBrightnessChromeLength;
const _kReaderBrightnessChromeDragHeight =
    _kReaderBrightnessChromeHeight - AppSpacing.sm * 2;
typedef _ReaderChromeOverlaySnapshot = ({
  bool chromeVisible,
  ReaderOverlay overlay,
});

String _readerBrightnessDebugValue(double? value) {
  if (value == null) return 'null';
  return '${(value * 100).round()}% (${value.toStringAsFixed(3)})';
}

String _readerBrightnessLabel(
  ReaderBrightnessState state, {
  required String systemLabel,
}) {
  if (!state.usesSystemBrightness) return '${state.percent}%';
  return systemLabel;
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
/// Tap-zone logic alone is not sufficient: a swipe would still turn the page
/// under the chrome. This barrier sits above the page but below the chrome
/// panels; any pointer on the page hides chrome and is not forwarded to the
/// page.
/// Comics keep page gestures available; their edge taps also hide chrome.
class ReaderChromeDismissBarrierDriver extends StatelessWidget {
  const ReaderChromeDismissBarrierDriver({super.key});

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
        (bloc) => isImagePageFormat(bloc.state.document?.format),
      ),
      chromeVisible: chromeOverlay.chromeVisible,
      overlayVisible: chromeOverlay.overlay != ReaderOverlay.none,
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
  const ReaderBrightnessChromeDriver({this.inChromeLayout = false, super.key});

  /// Placement belongs to [ReaderFloatingChromeLayout] when embedded there.
  final bool inChromeLayout;

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
        !hasSelection;
    final controlValue = brightnessState.controlValue;
    final waitingForSystemBrightness =
        brightnessState.usesSystemBrightness &&
        brightnessState.systemBrightness == null;

    return _ReaderBrightnessChrome(
      inChromeLayout: inChromeLayout,
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
    required this.inChromeLayout,
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

  final bool inChromeLayout;
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
    final dy = details.primaryDelta;
    if (dy == null || dy == 0) return;
    _updateDrag(-dy);
  }

  void _handleHorizontalDragUpdate(DragUpdateDetails details) {
    final dx = details.primaryDelta;
    if (dx == null || dx == 0) return;
    _updateDrag(Directionality.of(context) == TextDirection.rtl ? -dx : dx);
  }

  void _updateDrag(double distance) {
    if (!widget.dragEnabled) return;
    final brightnessRange =
        ReaderBrightnessCubit.maxBrightness -
        ReaderBrightnessCubit.minBrightness;
    final delta =
        distance / _kReaderBrightnessChromeDragHeight * brightnessRange;
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

    final pill = LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < _kReaderBrightnessChromeHeight;
        final direction = Directionality.of(context);
        return IgnorePointer(
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
                  width: compact
                      ? _kReaderBrightnessChromeHeight
                      : expanded
                      ? AppSizes.buttonHeight
                      : _kReaderBrightnessChromeWidth,
                  height: compact
                      ? AppSizes.buttonHeight
                      : _kReaderBrightnessChromeHeight,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: compact
                          ? AppSpacing.sm
                          : expanded
                          ? 0
                          : AppSpacing.xs,
                      vertical: compact ? 0 : AppSpacing.sm,
                    ),
                    child: Flex(
                      direction: compact ? Axis.horizontal : Axis.vertical,
                      // Increase is at the top vertically and at the logical end
                      // horizontally, without replacing the three control nodes.
                      textDirection: compact
                          ? direction == TextDirection.rtl
                                ? TextDirection.ltr
                                : TextDirection.rtl
                          : direction,
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
                          onVerticalDragUpdate: compact
                              ? null
                              : _handleVerticalDragUpdate,
                          onVerticalDragEnd: compact
                              ? null
                              : (_) => _flushDrag(),
                          onVerticalDragCancel: compact ? null : _flushDrag,
                          onHorizontalDragUpdate: compact
                              ? _handleHorizontalDragUpdate
                              : null,
                          onHorizontalDragEnd: compact
                              ? (_) => _flushDrag()
                              : null,
                          onHorizontalDragCancel: compact ? _flushDrag : null,
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
        );
      },
    );
    if (widget.inChromeLayout) return pill;
    return PositionedDirectional(
      top: 0,
      end: expanded ? AppSpacing.sm : AppSpacing.lg,
      bottom: 0,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Center(
          child: pill,
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
      child: AppSurface(
        color: active ? cs.selectedControlBackground : Colors.transparent,
        borderRadius: radius,
        child: AppTappable(
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
        !hasSelection;
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

/// Progress has a little more inset than the action targets below it.
const _kReaderProgressRowInset = AppSpacing.md;
const _kReaderProgressTrackHeight = readerChromeProgressTrackHeight;

/// Keeps article progress visible below the title, or at the safe top edge
/// when the title is hidden. Position updates rebuild only this indicator.
@visibleForTesting
class ReaderArticleProgressDriver extends StatelessWidget {
  const ReaderArticleProgressDriver({
    required this.readerTheme,
    this.inChromeLayout = false,
    super.key,
  });

  final ReaderThemeData readerTheme;
  final bool inChromeLayout;

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

    final line = IgnorePointer(
      child: Directionality(
        textDirection: document.$2 ? TextDirection.rtl : TextDirection.ltr,
        child: AppLinearProgressIndicator(
          key: const ValueKey('readerArticleProgress'),
          value: progress,
          minHeight: _kReaderProgressTrackHeight,
          color: readerChromeInkColor(readerTheme),
          backgroundColor: readerChromeTrackColor(readerTheme),
          borderRadius: BorderRadius.zero,
          semanticsLabel: context.l10n.librarySourcePercentRead(
            (progress * 100).round(),
          ),
        ),
      ),
    );
    if (inChromeLayout) {
      return AnimatedPadding(
        padding: EdgeInsets.only(
          top: titleVisible ? _kReaderTopChromeLineHeight : 0,
        ),
        duration: context.motion(AppMotion.short),
        curve: titleVisible ? _kChromeAnimCurve : _kChromeHideAnimCurve,
        child: line,
      );
    }
    return AnimatedPositioned(
      left: padding.left,
      right: padding.right,
      top: padding.top + (titleVisible ? _kReaderTopChromeLineHeight : 0),
      duration: context.motion(AppMotion.short),
      curve: titleVisible ? _kChromeAnimCurve : _kChromeHideAnimCurve,
      child: line,
    );
  }
}

/// Pulls title, chapter and chrome visibility for the top chrome line.
@visibleForTesting
class ReaderTopChromeDriver extends StatelessWidget {
  const ReaderTopChromeDriver({
    required this.readerTheme,
    this.onArticleTitlePressed,
    this.inChromeLayout = false,
    super.key,
  });

  final ReaderThemeData readerTheme;

  /// Placement belongs to [ReaderFloatingChromeLayout] when embedded there.
  final bool inChromeLayout;
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
      inChromeLayout: inChromeLayout,
      visible: chromeVisible && !hasSelection,
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
    required this.inChromeLayout,
    required this.visible,
    required this.line,
    required this.title,
    required this.textColor,
    required this.pageColor,
    this.onTitlePressed,
  });

  final bool visible;
  final bool inChromeLayout;
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

    final chrome = IgnorePointer(
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
    );
    if (inChromeLayout) return chrome;
    return Positioned(left: 0, right: 0, top: 0, child: chrome);
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
    return AppTooltip(
      message: label,
      child: Semantics(
        button: true,
        enabled: true,
        label: label,
        value: title,
        excludeSemantics: true,
        onTap: onPressed,
        child: AppSurface(
          color: Colors.transparent,
          borderRadius: radius,
          child: AppTappable(
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
    this.inChromeLayout = false,
    super.key,
  });

  final ReaderThemeData readerTheme;

  /// Placement belongs to [ReaderFloatingChromeLayout] when embedded there.
  final bool inChromeLayout;
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
    final visible = chromeVisible && !hasSelection;
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
        debugTraceReader(
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
          inChromeLayout: inChromeLayout,
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
    required this.inChromeLayout,
    required this.visible,
    required this.progress,
    required this.actions,
  });

  final bool inChromeLayout;
  final bool visible;
  final Widget progress;
  final Widget actions;

  @override
  Widget build(BuildContext context) {
    final chromeAnimCurve = visible ? _kChromeAnimCurve : _kChromeHideAnimCurve;
    final motion = context.motion(AppMotion.short);
    final surface = ToastAvoidArea(
      enabled: visible,
      child: _ReaderChromeDock(progress: progress, actions: actions),
    );
    final bottomInset = appBottomSafeInset(context);
    final placed = inChromeLayout
        ? Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: surface,
          )
        : SafeArea(
            top: false,
            bottom: false,
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: readerChromeDockMaxWidth,
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    bottomInset,
                  ),
                  child: surface,
                ),
              ),
            ),
          );
    final animated = IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, 1),
        duration: motion,
        curve: chromeAnimCurve,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: motion,
          curve: chromeAnimCurve,
          child: placed,
        ),
      ),
    );
    if (inChromeLayout) return animated;
    return Positioned(left: 0, right: 0, bottom: 0, child: animated);
  }
}

class _ReaderChromeDock extends StatelessWidget {
  const _ReaderChromeDock({required this.progress, required this.actions});

  final Widget progress;
  final Widget actions;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      key: const ValueKey('readerChromeDock'),
      role: AppSurfaceRole.floatingToolbar,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                _kReaderProgressRowInset,
                AppSpacing.md,
                _kReaderProgressRowInset,
                AppSpacing.sm,
              ),
              child: progress,
            ),
          ),
          actions,
        ],
      ),
    );
  }
}

/// Reader actions with at least 48dp targets and captions where they fit.
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
    final slots = <ReaderChromeActionData>[
      ReaderChromeActionData(
        label: l10n.readerBack,
        icon: AppIcons.back,
        iconSize: AppIconSize.lg,
        tooltip: l10n.readerBack,
        color: foregroundColor,
        onPressed: onBack,
      ),
      if (showTocAction)
        ReaderChromeActionData(
          label: l10n.readerContents,
          icon: AppIcons.toc,
          tooltip: l10n.readerContents,
          color: foregroundColor,
          onPressed: onTocPressed,
        ),
      if (showFontAction)
        ReaderChromeActionData(
          label: l10n.readerAppearanceTitle,
          icon: AppIcons.font,
          tooltip: fontActionTooltip,
          color: foregroundColor,
          onPressed: onFontPressed,
        ),
      if (showPageTurnAction)
        ReaderChromeActionData(
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
        ReaderChromeActionData(
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
        ReaderChromeActionData(
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
    if (context.isCupertino && AppWindowSize.isWide(context)) {
      return ReaderCupertinoChromeActions(
        actions: slots,
        labelStyle: labelStyle,
        showLabels: showLabels,
      );
    }
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
      height: showLabels ? labeledHeight : readerChromeActionStripHeight,
      child: Row(
        children: [
          for (final action in slots)
            Expanded(
              child: ReaderChromeActionButton(
                action: action,
                showLabel: showLabels,
              ),
            ),
        ],
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
    _dragReleaseTimer?.cancel();
    _dragReleaseTimer = null;
    final seekValue = _seekValue(value);
    setState(() {
      _isDragging = true;
      _dragValue = seekValue;
    });
  }

  void _handleChanged(double value) {
    // Native accessibility adjustments have no drag start/end callbacks.
    if (!_isDragging) {
      _handleChangeEnd(value);
      return;
    }
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
    final progressInset = readerProgressTrackInsetOf(context);
    final progressSlider = AppSlider(
      value: sliderValue,
      tapToSeek: true,
      activeColor: widget.inkColor,
      divisions: readerSliderDivisions(
        sourceType: widget.sourceType,
        format: widget.format,
        totalPages: widget.chapterTotalPages,
      ),
      onChangeStart: _handleChangeStart,
      onChanged: _handleChanged,
      onChangeEnd: _handleChangeEnd,
    );
    final progressTrack = showProgressSlider
        ? context.isCupertino
              ? progressSlider
              : SliderTheme(
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
                  child: progressSlider,
                )
        : Padding(
            padding: EdgeInsets.symmetric(
              horizontal: progressInset,
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

    final textScaler = MediaQuery.textScalerOf(context);
    final stacked = readerProgressLabelsStack(
      textScaler,
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
          Flexible(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: progressInset,
              ),
              child: ReaderProgressLabelLayout(
                start: startText,
                page: pageText,
                preferStacked: stacked,
              ),
            ),
          ),
          SizedBox(height: AppSizes.buttonHeight, child: progressTrack),
        ],
      ),
    );
  }
}

/// Feeds image-page progress metrics into the transient CBZ page overlay.
class ReaderImagePageProgressOverlayDriver extends StatelessWidget {
  const ReaderImagePageProgressOverlayDriver({super.key});

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
      selectionActionsVisible: hasSelection,
      currentPage: current,
      totalPages: total,
    );
  }
}
