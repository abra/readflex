import 'dart:math' as math;
import 'dart:ui';

/// Places area actions outside the crop when possible, leaving corner targets
/// clear. A tall crop uses its interior instead of covering a screen-edge handle.
double imageSelectionPopupTop({
  required double viewportHeight,
  required double safeTop,
  required double safeBottom,
  required double popupHeight,
  required double edgeInset,
  required double cornerClearance,
  required Rect? selection,
}) {
  final minTop = safeTop + edgeInset;
  final maxTop = math.max(
    minTop,
    viewportHeight - safeBottom - edgeInset - popupHeight,
  );
  if (selection == null) return maxTop;

  final above = selection.top - cornerClearance - popupHeight;
  if (above >= minTop) return above.clamp(minTop, maxTop).toDouble();
  final below = selection.bottom + cornerClearance;
  if (below <= maxTop) return below.clamp(minTop, maxTop).toDouble();

  final insideTop = math.max(minTop, selection.top + cornerClearance);
  final insideBottom = math.min(
    maxTop,
    selection.bottom - cornerClearance - popupHeight,
  );
  if (insideTop <= insideBottom) return insideBottom;
  return (minTop + maxTop) / 2;
}
