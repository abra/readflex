import 'package:flutter/material.dart';

import 'top_scroll_under_scrim.dart';

/// Wraps a scrollable [child] in a stack that overlays a top and bottom
/// [ScrollEdgeFade] reflecting whether content extends past the visible
/// viewport. The fades fade in/out automatically as the user scrolls.
///
/// Listens to a single descendant vertical scrollable through
/// [NotificationListener]<[ScrollNotification]>; the [child] can be any
/// composition that ultimately contains one — `ListView`, `GridView`,
/// `CustomScrollView`, or a `RefreshIndicator` wrapping any of those.
///
/// Use this anywhere a tab-bar / bottom-nav overlaps the lower edge of a
/// long list and a hairline fade improves the visual hint that more
/// content is below.
class ScrollEdgeFadeStack extends StatefulWidget {
  const ScrollEdgeFadeStack({super.key, required this.child});

  final Widget child;

  @override
  State<ScrollEdgeFadeStack> createState() => _ScrollEdgeFadeStackState();
}

class _ScrollEdgeFadeStackState extends State<ScrollEdgeFadeStack> {
  // Top hairline starts hidden — viewport is at offset 0 on first build.
  bool _showTop = false;
  // Bottom hairline starts visible: assume the list is taller than the
  // viewport. The first vertical scroll notification will correct it
  // (extentAfter == 0 → fade out) for short lists.
  bool _showBottom = true;

  bool _onNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    final showTop = notification.metrics.extentBefore > 0;
    final showBottom = notification.metrics.extentAfter > 0;
    if ((showTop != _showTop || showBottom != _showBottom) && mounted) {
      setState(() {
        _showTop = showTop;
        _showBottom = showBottom;
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: _onNotification,
          child: widget.child,
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: ScrollEdgeFade(visible: _showTop),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: ScrollEdgeFade(
            visible: _showBottom,
            edge: ScrollFadeEdge.bottom,
          ),
        ),
      ],
    );
  }
}
