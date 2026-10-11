import 'package:component_library/component_library.dart';
import 'package:flutter/widgets.dart';

import 'library_layout.dart';

/// The filled part of a Library progress bar, from the start edge. It eases
/// to a new value over [AppMotion.short] with [kLibraryProgressFillCurve].
///
/// A value that changes while the route is covered (its tickers are off, as
/// under the reader) is held until the route shows again. Started while
/// covered, the animation would run out of sight: a ticker started during a
/// frame keeps that frame's time, so it would already be over on return.
class LibraryProgressFill extends StatefulWidget {
  const LibraryProgressFill({
    required this.progress,
    required this.color,
    this.fillKey,
    super.key,
  });

  /// Filled fraction; clamped to 0..1.
  final double progress;
  final Color color;

  /// Key of the filled box, for tests that measure it.
  final Key? fillKey;

  @override
  State<LibraryProgressFill> createState() => _LibraryProgressFillState();
}

class _LibraryProgressFillState extends State<LibraryProgressFill> {
  late double _shown = _target;

  double get _target => widget.progress.clamp(0.0, 1.0).toDouble();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _showTargetIfVisible();
  }

  @override
  void didUpdateWidget(LibraryProgressFill oldWidget) {
    super.didUpdateWidget(oldWidget);
    _showTargetIfVisible();
  }

  void _showTargetIfVisible() {
    if (TickerMode.valuesOf(context).enabled) _shown = _target;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedFractionallySizedBox(
      duration: context.motion(AppMotion.short),
      curve: kLibraryProgressFillCurve,
      alignment: AlignmentDirectional.centerStart,
      widthFactor: _shown,
      child: ColoredBox(key: widget.fillKey, color: widget.color),
    );
  }
}
