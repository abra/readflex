import 'package:flutter/material.dart';

/// A gradient overlay pinned to the bottom of a [Stack].
///
/// Fades from transparent at the top to the scaffold background color at the
/// bottom. Wraps itself in [Positioned] and [IgnorePointer] so it sits above
/// scrollable content without blocking taps.
class FadeGradientOverlay extends StatelessWidget {
  const FadeGradientOverlay({required this.height, super.key});

  final double height;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).scaffoldBackgroundColor;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: height,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [color.withValues(alpha: 0), color],
            ),
          ),
        ),
      ),
    );
  }
}
