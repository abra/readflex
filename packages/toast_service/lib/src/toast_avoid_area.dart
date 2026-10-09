import 'dart:math' as math;
import 'dart:ui' show FlutterView;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Marks controls at the bottom of the screen that a toast must not cover,
/// such as the Library capsule, the selection bar or the reader's bottom
/// chrome. [showToast] floats toasts above the highest marked area that is
/// on screen when the toast appears.
///
/// Only the area's own layout box counts; it costs nothing until a toast is
/// shown, when each mounted area reports its top edge once.
class ToastAvoidArea extends StatefulWidget {
  const ToastAvoidArea({required this.child, this.enabled = true, super.key});

  /// False while the area stays mounted but hidden, like reader chrome that
  /// slid out of view.
  final bool enabled;
  final Widget child;

  @override
  State<ToastAvoidArea> createState() => _ToastAvoidAreaState();
}

final _areas = <_ToastAvoidAreaState>{};

class _ToastAvoidAreaState extends State<ToastAvoidArea> {
  FlutterView? _view;
  bool _onstage = true;

  @override
  void initState() {
    super.initState();
    _areas.add(this);
  }

  @override
  void dispose() {
    _areas.remove(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _view = View.maybeOf(context);
    // A route under an opaque one stays mounted, offstage with its tickers
    // muted; its controls are not on screen.
    _onstage = TickerMode.valuesOf(context).enabled;
    return widget.child;
  }

  /// The area's top edge in [view], in logical pixels, or null when it is
  /// hidden, offstage or not laid out.
  double? topIn(FlutterView view) {
    if (!widget.enabled || !_onstage || _view != view) return null;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return _restingTop(box);
  }
}

/// The box's top from layout offsets alone, ignoring paint transforms, so a
/// control in the middle of an entrance scale or slide (the Library capsule
/// growing in after selection) reports where it comes to rest.
double _restingTop(RenderBox box) {
  var top = 0.0;
  RenderObject? node = box;
  while (node != null) {
    final parentData = node.parentData;
    if (parentData is BoxParentData) top += parentData.offset.dy;
    node = node.parent;
  }
  return top;
}

/// How far above the bottom edge of [view] the highest marked area reaches,
/// in logical pixels; 0 when none is on screen. Areas whose top is in the
/// upper half of the view are not bottom controls and are ignored.
double toastAvoidClearance(FlutterView view) {
  final height = view.physicalSize.height / view.devicePixelRatio;
  var clearance = 0.0;
  for (final area in _areas) {
    final top = area.topIn(view);
    if (top == null || top < height / 2) continue;
    clearance = math.max(clearance, height - top);
  }
  return clearance;
}
