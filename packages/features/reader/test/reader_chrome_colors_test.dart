import 'dart:math' as math;

import 'package:component_library/component_library.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_chrome_colors.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  for (final preset in ReaderThemePreset.values) {
    final theme = preset.data;

    test('${preset.id} chrome ink keeps 4.5:1 on the page', () {
      final ink = readerChromeInkColor(theme);
      expect(
        ink.a,
        1,
        reason:
            'opaque, so contrast does not depend on what '
            'is behind the line',
      );
      expect(
        _contrast(ink, theme.backgroundColor),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('${preset.id} chrome ink is muted relative to the page text', () {
      final ink = readerChromeInkColor(theme);
      expect(
        _contrast(ink, theme.backgroundColor),
        lessThan(_contrast(theme.primaryTextColor, theme.backgroundColor)),
      );
    });

    test('${preset.id} track sits between the page and the ink', () {
      final track = readerChromeTrackColor(theme);
      final ink = readerChromeInkColor(theme);
      expect(track.a, 1);
      final trackContrast = _contrast(track, theme.backgroundColor);
      expect(trackContrast, greaterThan(1));
      expect(trackContrast, lessThan(_contrast(ink, theme.backgroundColor)));
      // The thumb must stand out from the unfilled track it rides on.
      expect(_contrast(ink, track), greaterThanOrEqualTo(3));
    });
  }
}
