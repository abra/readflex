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
  // Both fades start hidden. We rely on [ScrollMetricsNotification]
  // (fired on the first layout and on every resize, no gesture
  // needed) to flip them on for long lists. Defaulting to `true`
  // would leave a permanent bottom shadow on lists that fit the
  // viewport — they never produce a ScrollNotification.
  bool _showTop = false;
  bool _showBottom = false;

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
