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
///
/// With [axis] set to [Axis.horizontal] it watches a horizontal scrollable
/// (a scrolling tab bar) instead and dissolves its start and end edges into
/// [surfaceColor], so a label cut by the screen edge reads as "scroll for
/// more" rather than as clipped text. Start and end follow the scroll
/// direction, so right-to-left strips fade on the correct sides.
class ScrollEdgeFadeStack extends StatefulWidget {
  const ScrollEdgeFadeStack({
    super.key,
    required this.child,
    this.showBottomFade = true,
    this.axis = Axis.vertical,
    this.surfaceColor,
    this.fadeInsets = EdgeInsets.zero,
    this.enabled = true,
  });

  /// Width of the horizontal fades: about two glyphs of a small label.
  static const horizontalFadeWidth = 32.0;

  final Widget child;

  /// Whether to paint the lower edge fade when content continues below.
  /// Vertical stacks only.
  final bool showBottomFade;

  /// Scroll axis of the watched scrollable.
  final Axis axis;

  /// Background the horizontal fades dissolve into; see
  /// [ScrollEdgeFade.surfaceColor]. Ignored for vertical stacks.
  final Color? surfaceColor;

  /// Top and bottom insets of the horizontal fades, so a divider under a
  /// tab bar stays whole while its labels fade. Ignored for vertical stacks.
  final EdgeInsets fadeInsets;

  /// Whether the fades may show. A child that stops scrolling sends no
  /// notification (a tab bar whose tabs now fill the width), so its owner
  /// turns this off; the stack then hides both fades and forgets the last
  /// metrics until a new scrollable reports.
  final bool enabled;

  @override
  State<ScrollEdgeFadeStack> createState() => _ScrollEdgeFadeStackState();
}

class _ScrollEdgeFadeStackState extends State<ScrollEdgeFadeStack> {
  // Both fades start hidden. We rely on [ScrollMetricsNotification]
  // (fired on the first layout and on every resize, no gesture
  // needed) to flip them on for long lists. Defaulting to `true`
  // would leave a permanent bottom shadow on lists that fit the
  // viewport — they never produce a ScrollNotification.
  // Top/bottom for vertical stacks, start/end for horizontal ones.
  bool _showTop = false;
  bool _showBottom = false;

  void _updateFromMetrics(ScrollMetrics metrics) {
    if (!widget.enabled || metrics.axis != widget.axis) return;
    final bool showTop;
    final bool showBottom;
    if (widget.axis == Axis.vertical) {
      showTop = metrics.extentBefore > 0;
      showBottom = widget.showBottomFade && metrics.extentAfter > 0;
    } else {
      // Content "before" the viewport sits at the reading start when the
      // strip scrolls in the reading direction (a TabBar does in LTR and
      // RTL); a reversed strip swaps the sides.
      final readingAxis = Directionality.of(context) == TextDirection.rtl
          ? AxisDirection.left
          : AxisDirection.right;
      final forward = metrics.axisDirection == readingAxis;
      showTop = forward ? metrics.extentBefore > 0 : metrics.extentAfter > 0;
      showBottom = forward ? metrics.extentAfter > 0 : metrics.extentBefore > 0;
    }
    if ((showTop != _showTop || showBottom != _showBottom) && mounted) {
      setState(() {
        _showTop = showTop;
        _showBottom = showBottom;
      });
    }
  }

  @override
  void didUpdateWidget(covariant ScrollEdgeFadeStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) {
      _showTop = false;
      _showBottom = false;
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
    // Two listeners: ScrollMetricsNotification (fires on first layout /
    // resize / content-size change without a gesture) and
    // ScrollNotification (fires on scroll events). The metrics one is what
    // flips a fade on when new content overflows; without it the fade only
    // appears after a manual scroll. ScrollMetricsNotification is NOT a
    // ScrollNotification subclass, so a single listener can't catch both.
    final listener = NotificationListener<ScrollMetricsNotification>(
      onNotification: _onMetrics,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: widget.child,
      ),
    );
    if (widget.axis == Axis.horizontal) {
      return Stack(
        children: [
          listener,
          PositionedDirectional(
            start: 0,
            top: widget.fadeInsets.top,
            bottom: widget.fadeInsets.bottom,
            child: ScrollEdgeFade(
              visible: _showTop,
              edge: ScrollFadeEdge.start,
              height: ScrollEdgeFadeStack.horizontalFadeWidth,
              surfaceColor: widget.surfaceColor,
            ),
          ),
          PositionedDirectional(
            end: 0,
            top: widget.fadeInsets.top,
            bottom: widget.fadeInsets.bottom,
            child: ScrollEdgeFade(
              visible: _showBottom,
              edge: ScrollFadeEdge.end,
              height: ScrollEdgeFadeStack.horizontalFadeWidth,
              surfaceColor: widget.surfaceColor,
            ),
          ),
        ],
      );
    }
    return Stack(
      children: [
        listener,
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
