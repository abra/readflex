import 'package:flutter/material.dart';

/// The edge from which the fade originates.
enum ScrollFadeEdge { top, bottom }

/// A gradient fade at the edge of a scrollable area indicating
/// that content extends beyond the viewport.
///
/// Place inside a [Stack] with `Positioned(top: 0)` or `Positioned(bottom: 0)`.
class ScrollEdgeFade extends StatelessWidget {
  const ScrollEdgeFade({
    super.key,
    required this.visible,
    this.edge = ScrollFadeEdge.top,
    this.height = 18,
  });

  final bool visible;
  final ScrollFadeEdge edge;
  final double height;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isTop = edge == ScrollFadeEdge.top;

    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: SizedBox(
          height: height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: isTop ? Alignment.topCenter : Alignment.bottomCenter,
                end: isTop ? Alignment.bottomCenter : Alignment.topCenter,
                colors: isDark
                    ? [
                        Colors.black.withValues(alpha: 0.24),
                        Colors.black.withValues(alpha: 0.12),
                        Colors.black.withValues(alpha: 0),
                      ]
                    : [
                        Colors.black.withValues(alpha: 0.08),
                        Colors.black.withValues(alpha: 0.03),
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
