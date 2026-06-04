import 'dart:async';

import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'reader_tap_action.dart';
import 'reader_ui_cubit.dart';

const _kReaderTapZoneHintVisibleDuration = Duration(milliseconds: 1700);
const _kReaderTapZoneHintFadeDuration = Duration(milliseconds: 180);

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

class _ReaderTapZoneHintOverlay extends StatelessWidget {
  const _ReaderTapZoneHintOverlay({
    required this.axis,
    required this.readerTheme,
  });

  final ReaderTapAxis axis;
  final ReaderThemeData readerTheme;

  @override
  Widget build(BuildContext context) {
    final fill = readerTheme.accentColor.withValues(alpha: 0.12);
    final border = readerTheme.accentColor.withValues(alpha: 0.30);
    final icon = readerTheme.accentColor.withValues(alpha: 0.88);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        return Stack(
          children: axis == ReaderTapAxis.vertical
              ? [
                  Positioned(
                    left: width * readerLeftTapZoneEnd,
                    top: 0,
                    width:
                        width *
                        (readerRightTapZoneStart - readerLeftTapZoneEnd),
                    height: height * readerTopTapZoneEnd,
                    child: _ReaderTapZoneHintPanel(
                      icon: Icons.keyboard_arrow_up_rounded,
                      fill: fill,
                      border: border,
                      iconColor: icon,
                    ),
                  ),
                  Positioned(
                    left: width * readerLeftTapZoneEnd,
                    bottom: 0,
                    width:
                        width *
                        (readerRightTapZoneStart - readerLeftTapZoneEnd),
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
