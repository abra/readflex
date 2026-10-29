import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// The active search tint's colour, opaque: the marker's.
const readerSearchOcclusionColor = Color(0xFFFFB300);

/// Where the active search hit is hidden under the search bar, which
/// covers the bottom [bottomInset] share of a view of [size]: each span
/// of [rects] (the hit's boxes in the view) reaching into that band,
/// clipped to the view's width, overlapping spans merged so a hit over
/// several lines marks once. Empty when the bar covers nothing.
@visibleForTesting
List<({double left, double width})> occludedSearchSpans(
  List<Rect> rects,
  Size size,
  double bottomInset,
) {
  if (size.isEmpty || bottomInset <= 0 || bottomInset >= 1) return const [];
  final edge = size.height * (1 - bottomInset);
  final intervals = <(double, double)>[];
  for (final rect in rects) {
    if (!rect.isFinite || rect.right <= rect.left) continue;
    if (rect.bottom <= rect.top || rect.bottom <= edge) continue;
    if (rect.top >= size.height) continue;
    final start = rect.left.clamp(0.0, size.width);
    final end = rect.right.clamp(0.0, size.width);
    if (end > start) intervals.add((start, end));
  }
  intervals.sort((a, b) => a.$1.compareTo(b.$1));
  final merged = <(double, double)>[];
  for (final (start, end) in intervals) {
    if (merged.isNotEmpty && start <= merged.last.$2) {
      final last = merged.removeLast();
      merged.add((last.$1, end > last.$2 ? end : last.$2));
    } else {
      merged.add((start, end));
    }
  }
  return [for (final (start, end) in merged) (left: start, width: end - start)];
}

/// Marks where the active search hit is while the search bar covers it:
/// a short bar on the bar's top edge above each part of the hit. Draws
/// nothing over the page otherwise and never takes a touch.
class ReaderSearchOcclusionMarker extends StatelessWidget {
  const ReaderSearchOcclusionMarker({
    super.key,
    required this.rects,
    required this.bottomInset,
  });

  /// The active hit's boxes in this widget's coordinates.
  final ValueListenable<List<Rect>> rects;

  /// The share of the height the search bar covers.
  final double bottomInset;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(
      size: Size.infinite,
      painter: _OcclusionPainter(rects, bottomInset),
    ),
  );
}

class _OcclusionPainter extends CustomPainter {
  _OcclusionPainter(this.rects, this.bottomInset) : super(repaint: rects);

  final ValueListenable<List<Rect>> rects;
  final double bottomInset;

  static const _height = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final spans = occludedSearchSpans(rects.value, size, bottomInset);
    if (spans.isEmpty) return;
    final top = size.height * (1 - bottomInset) - _height;
    final paint = Paint()..color = readerSearchOcclusionColor;
    for (final span in spans) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(span.left, top, span.width, _height),
          const Radius.circular(_height / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_OcclusionPainter old) =>
      old.rects != rects || old.bottomInset != bottomInset;
}
