import 'package:flutter/material.dart';

import 'theme/extensions/build_context_ext.dart';
import 'theme/tokens/app_motion.dart';

/// The edge from which the fade originates. [start]/[end] are horizontal
/// and resolve against the ambient text direction (a chip strip, a swatch
/// strip); [top]/[bottom] are vertical (a list under a footer).
enum ScrollFadeEdge { top, bottom, start, end }

/// A gradient fade at the edge of a scrollable area indicating
/// that content extends beyond the viewport.
///
/// Vertical edges darken (a list hiding under a footer). Horizontal edges
/// dissolve the strip into [surfaceColor] instead: a dark smudge beside a
/// filled control reads as a rendering glitch, not a scroll hint.
///
/// Place inside a [Stack] with `Positioned(top: 0)` or `Positioned(bottom: 0)`.
class ScrollEdgeFade extends StatelessWidget {
  const ScrollEdgeFade({
    super.key,
    required this.visible,
    this.edge = ScrollFadeEdge.top,
    this.height = 18,
    this.surfaceColor,
  });

  final bool visible;
  final ScrollFadeEdge edge;

  /// Thickness of the fade along its axis (height for top/bottom, width
  /// for start/end).
  final double height;

  /// Background the strip dissolves into for [ScrollFadeEdge.start] /
  /// [ScrollFadeEdge.end]. Defaults to the scaffold background; sheets pass
  /// their own surface. Ignored for vertical edges.
  final Color? surfaceColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final horizontal =
        edge == ScrollFadeEdge.start || edge == ScrollFadeEdge.end;
    final surface = surfaceColor ?? theme.scaffoldBackgroundColor;
    final (begin, end) = switch (edge) {
      ScrollFadeEdge.top => (Alignment.topCenter, Alignment.bottomCenter),
      ScrollFadeEdge.bottom => (Alignment.bottomCenter, Alignment.topCenter),
      ScrollFadeEdge.start => (
        AlignmentDirectional.centerStart,
        AlignmentDirectional.centerEnd,
      ),
      ScrollFadeEdge.end => (
        AlignmentDirectional.centerEnd,
        AlignmentDirectional.centerStart,
      ),
    };

    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: context.motion(AppMotion.short),
        curve: Curves.easeOut,
        child: SizedBox(
          height: horizontal ? null : height,
          width: horizontal ? height : null,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: begin,
                end: end,
                colors: horizontal
                    ? [
                        surface,
                        surface.withValues(alpha: 0.6),
                        surface.withValues(alpha: 0),
                      ]
                    : isDark
                    ? [
                        Colors.black.withValues(alpha: 0.24),
                        Colors.black.withValues(alpha: 0.12),
                        Colors.black.withValues(alpha: 0),
                      ]
                    : [
                        // 0.08 vanished on gray50 surfaces; the fade is the
                        // only cue that a footer hides more content.
                        Colors.black.withValues(alpha: 0.14),
                        Colors.black.withValues(alpha: 0.05),
                        Colors.black.withValues(alpha: 0),
                      ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
