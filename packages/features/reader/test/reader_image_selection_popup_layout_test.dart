import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_image_selection_popup_layout.dart';

void main() {
  double top(Rect? selection, {double viewportHeight = 844}) =>
      imageSelectionPopupTop(
        viewportHeight: viewportHeight,
        safeTop: 24,
        safeBottom: 34,
        popupHeight: 52,
        edgeInset: 8,
        cornerClearance: 56,
        selection: selection,
      );

  test('a normal crop leaves its upper corner targets clear', () {
    const selection = Rect.fromLTWH(150, 350, 90, 90);
    expect(top(selection) + 52, lessThanOrEqualTo(selection.top - 56));
  });

  test('a crop near the top puts actions below its lower targets', () {
    const selection = Rect.fromLTWH(150, 45, 90, 90);
    expect(top(selection), greaterThanOrEqualTo(selection.bottom + 56));
  });

  test('a tall crop uses its interior without covering corner targets', () {
    const selection = Rect.fromLTRB(156, 42, 234, 802);
    final popup = Rect.fromLTWH(19, top(selection), 352, 52);
    for (final corner in [
      selection.topLeft,
      selection.topRight,
      selection.bottomLeft,
      selection.bottomRight,
    ]) {
      expect(
        popup.overlaps(Rect.fromCenter(center: corner, width: 96, height: 96)),
        isFalse,
      );
    }
    expect(popup.top, greaterThanOrEqualTo(32));
    expect(popup.bottom, lessThanOrEqualTo(802));
  });

  test('zoomed crop outside viewport leaves the actions reachable', () {
    const selection = Rect.fromLTRB(-100, -300, 600, 1500);
    expect(top(selection), inInclusiveRange(32, 750));
    expect(top(null), 750);
  });
}
