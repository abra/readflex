import 'package:flutter/material.dart';

import 'top_scroll_under_scrim.dart';

/// Wraps a scrollable [child] in a stack that overlays edge
/// [ScrollEdgeFade]s reflecting whether content extends past the visible
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
  const ScrollEdgeFadeStack({
    super.key,
    required this.child,
    this.showBottomFade = true,
  });

  final Widget child;

  /// Whether to paint the lower edge fade when content continues below.
  final bool showBottomFade;

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

  void _updateFromMetrics(ScrollMetrics metrics) {
    if (metrics.axis != Axis.vertical) return;
    final showTop = metrics.extentBefore > 0;
    final showBottom = widget.showBottomFade && metrics.extentAfter > 0;
    if ((showTop != _showTop || showBottom != _showBottom) && mounted) {
      setState(() {
        _showTop = showTop;
        _showBottom = showBottom;
      });
    }
  }

  bool _onScroll(ScrollNotification notification) {
    _updateFromMetrics(notification.metrics);
    return false;
  }

  bool _onMetrics(ScrollMetricsNotification notification) {
    _updateFromMetrics(notification.metrics);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Two listeners: ScrollMetricsNotification (fires on first
        // layout / resize / content-size change without a gesture)
        // and ScrollNotification (fires on scroll events). The
        // metrics one is what flips the bottom fade on when the
        // user switches grid → list and the new list overflows;
        // without it the fade only appears after a manual scroll.
        // ScrollMetricsNotification is NOT a ScrollNotification
        // subclass, so a single listener can't catch both.
        NotificationListener<ScrollMetricsNotification>(
          onNotification: _onMetrics,
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: widget.child,
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: ScrollEdgeFade(visible: _showTop),
        ),
        if (widget.showBottomFade)
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
