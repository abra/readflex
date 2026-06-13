import 'dart:async';

import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'reader_tap_action.dart';
import 'reader_ui_cubit.dart';

const _kReaderTapZoneHintVisibleDuration = Duration(milliseconds: 1700);
const _kReaderTapZoneHintFadeDuration = Duration(milliseconds: 180);
const _kReaderTapEdgeThickness = 2.0;
const _kReaderTapEdgeInset = 4.0;
const _kReaderTapEdgeMinLength = 18.0;
const _kReaderTapEdgeMaxLength = 28.0;

class ReaderTapEdgeIndicator extends StatelessWidget {
  const ReaderTapEdgeIndicator({
    required this.readerTheme,
    required this.axis,
    required this.pageProgressionRtl,
    required this.canGoPrevious,
    required this.canGoNext,
    required this.contentTopMargin,
    required this.contentBottomMargin,
    required this.contentSideMargin,
    this.visible = true,
    super.key,
  });

  final ReaderThemeData readerTheme;
  final ReaderTapAxis axis;
  final bool pageProgressionRtl;
  final bool canGoPrevious;
  final bool canGoNext;
  final double contentTopMargin;
  final double contentBottomMargin;
  final double contentSideMargin;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    final color = readerTheme.primaryTextColor.withValues(alpha: 0.35);
    return Positioned.fill(
      child: IgnorePointer(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            final metrics = _ReaderTapEdgeMetrics(
              width: width,
              height: height,
              topMargin: contentTopMargin,
              bottomMargin: contentBottomMargin,
              sideMarginPercent: contentSideMargin,
            );
            return Stack(
              children: axis == ReaderTapAxis.vertical
                  ? _verticalLines(metrics, color)
                  : _horizontalLines(metrics, color),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _verticalLines(_ReaderTapEdgeMetrics metrics, Color color) {
    final lineWidth = (metrics.contentWidth * 0.07)
        .clamp(_kReaderTapEdgeMinLength, _kReaderTapEdgeMaxLength)
        .toDouble();
    final lineLeft =
        metrics.contentLeft + (metrics.contentWidth - lineWidth) / 2;
    return [
      if (canGoPrevious)
        Positioned(
          key: const Key('readerTapEdgeTop'),
          left: lineLeft,
          top: metrics.topLineInset,
          width: lineWidth,
          height: _kReaderTapEdgeThickness,
          child: _ReaderTapEdgeLine(color: color),
        ),
      if (canGoNext)
        Positioned(
          key: const Key('readerTapEdgeBottom'),
          left: lineLeft,
          bottom: metrics.bottomLineInset,
          width: lineWidth,
          height: _kReaderTapEdgeThickness,
          child: _ReaderTapEdgeLine(color: color),
        ),
    ];
  }

  List<Widget> _horizontalLines(_ReaderTapEdgeMetrics metrics, Color color) {
    final canGoLeft = pageProgressionRtl ? canGoNext : canGoPrevious;
    final canGoRight = pageProgressionRtl ? canGoPrevious : canGoNext;
    final lineHeight = (metrics.contentHeight * 0.05)
        .clamp(_kReaderTapEdgeMinLength, _kReaderTapEdgeMaxLength)
        .toDouble();
    final lineTop =
        metrics.contentTop + (metrics.contentHeight - lineHeight) / 2;
    return [
      if (canGoLeft)
        Positioned(
          key: const Key('readerTapEdgeLeft'),
          left: _kReaderTapEdgeInset,
          top: lineTop,
          width: _kReaderTapEdgeThickness,
          height: lineHeight,
          child: _ReaderTapEdgeLine(color: color),
        ),
      if (canGoRight)
        Positioned(
          key: const Key('readerTapEdgeRight'),
          right: _kReaderTapEdgeInset,
          top: lineTop,
          width: _kReaderTapEdgeThickness,
          height: lineHeight,
          child: _ReaderTapEdgeLine(color: color),
        ),
    ];
  }
}

/// Geometry helper that maps reader margins into visible tap-edge line bounds.
class _ReaderTapEdgeMetrics {
  _ReaderTapEdgeMetrics({
    required this.width,
    required this.height,
    required double topMargin,
    required double bottomMargin,
    required double sideMarginPercent,
  }) : contentTop = topMargin.clamp(0.0, height).toDouble(),
       contentBottom = bottomMargin.clamp(0.0, height).toDouble(),
       contentLeft = (width * sideMarginPercent / 100)
           .clamp(0.0, width / 2)
           .toDouble();

  final double width;
  final double height;
  final double contentTop;
  final double contentBottom;
  final double contentLeft;

  double get contentRight => contentLeft;

  double get contentWidth =>
      (width - contentLeft - contentRight).clamp(0.0, width).toDouble();

  double get contentHeight =>
      (height - contentTop - contentBottom).clamp(0.0, height).toDouble();

  double get topLineInset => _lineInsetForMargin(contentTop);

  double get bottomLineInset => _lineInsetForMargin(contentBottom);

  double get leftLineInset => _lineInsetForMargin(contentLeft);

  double get rightLineInset => _lineInsetForMargin(contentRight);

  static double _lineInsetForMargin(double margin) =>
      (margin - _kReaderTapEdgeInset - _kReaderTapEdgeThickness)
          .clamp(0.0, margin)
          .toDouble();
}

class _ReaderTapEdgeLine extends StatelessWidget {
  const _ReaderTapEdgeLine({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(_kReaderTapEdgeThickness),
      ),
    );
  }
}

class ReaderTapZoneHintDriver extends StatefulWidget {
  const ReaderTapZoneHintDriver({required this.readerTheme, super.key});

  final ReaderThemeData readerTheme;

  @override
  State<ReaderTapZoneHintDriver> createState() =>
      _ReaderTapZoneHintDriverState();
}

class _ReaderTapZoneHintDriverState extends State<ReaderTapZoneHintDriver>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _hideTimer;
  ReaderTapAxis? _axis;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _kReaderTapZoneHintFadeDuration,
      reverseDuration: _kReaderTapZoneHintFadeDuration,
    );
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _show(ReaderTapAxis axis) {
    _hideTimer?.cancel();
    setState(() => _axis = axis);
    _controller.forward(from: 0);
    _hideTimer = Timer(_kReaderTapZoneHintVisibleDuration, () {
      if (!mounted) return;
      _controller.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ReaderUiCubit, ReaderUiState>(
      listenWhen: (previous, current) =>
          previous.tapZoneHintToken != current.tapZoneHintToken,
      listener: (_, state) {
        final axis = state.tapZoneHintAxis;
        if (axis != null) _show(axis);
      },
      child: Positioned.fill(
        child: IgnorePointer(
          child: FadeTransition(
            opacity: CurvedAnimation(
              parent: _controller,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            ),
            child: _axis == null
                ? const SizedBox.shrink()
                : _ReaderTapZoneHintOverlay(
                    axis: _axis!,
                    readerTheme: widget.readerTheme,
                  ),
          ),
        ),
      ),
    );
  }
}

/// Full-screen transient overlay that visualizes current page-turn tap zones.
class _ReaderTapZoneHintOverlay extends StatelessWidget {
  const _ReaderTapZoneHintOverlay({
    required this.axis,
    required this.readerTheme,
  });

  final ReaderTapAxis axis;
  final ReaderThemeData readerTheme;

  @override
  Widget build(BuildContext context) {
    final fill = readerTheme.accentColor.withValues(alpha: 0.45);
    final border = readerTheme.accentColor.withValues(alpha: 0.65);
    final icon = Colors.white;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        return Stack(
          children: axis == ReaderTapAxis.vertical
              ? [
                  Positioned(
                    left: 0,
                    top: 0,
                    width: width,
                    height: height * readerTopTapZoneEnd,
                    child: _ReaderTapZoneHintPanel(
                      icon: Icons.keyboard_arrow_up_rounded,
                      fill: fill,
                      border: border,
                      iconColor: icon,
                    ),
                  ),
                  Positioned(
                    left: 0,
                    bottom: 0,
                    width: width,
                    height: height * (1 - readerBottomTapZoneStart),
                    child: _ReaderTapZoneHintPanel(
                      icon: Icons.keyboard_arrow_down_rounded,
                      fill: fill,
                      border: border,
                      iconColor: icon,
                    ),
                  ),
                ]
              : [
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: width * readerLeftTapZoneEnd,
                    child: _ReaderTapZoneHintPanel(
                      icon: Icons.keyboard_arrow_left_rounded,
                      fill: fill,
                      border: border,
                      iconColor: icon,
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    width: width * (1 - readerRightTapZoneStart),
                    child: _ReaderTapZoneHintPanel(
                      icon: Icons.keyboard_arrow_right_rounded,
                      fill: fill,
                      border: border,
                      iconColor: icon,
                    ),
                  ),
                ],
        );
      },
    );
  }
}

/// Single highlighted tap-zone panel used by [_ReaderTapZoneHintOverlay].
class _ReaderTapZoneHintPanel extends StatelessWidget {
  const _ReaderTapZoneHintPanel({
    required this.icon,
    required this.fill,
    required this.border,
    required this.iconColor,
  });

  final IconData icon;
  final Color fill;
  final Color border;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: border),
      ),
      child: Center(
        child: FittedBox(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 44,
                color: iconColor,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                'TAP AREA',
                style: TextStyle(
                  color: iconColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
