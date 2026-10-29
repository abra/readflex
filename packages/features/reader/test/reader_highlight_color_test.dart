import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_highlight_color.dart';

void main() {
  group('readerHighlightColor', () {
    test('uses the reader theme color for each highlight option', () {
      final theme = ReaderThemePreset.paper.data;

      expect(
        readerHighlightColor(HighlightColor.yellow, theme),
        const Color(0xFFF6E7AC),
      );
      expect(
        readerHighlightColor(HighlightColor.green, theme),
        const Color(0xFFBCE6D1),
      );
      expect(
        readerHighlightColor(HighlightColor.blue, theme),
        const Color(0xFFC2D9F0),
      );
      expect(
        readerHighlightColor(HighlightColor.pink, theme),
        const Color(0xFFEAB8C9),
      );
      expect(
        readerHighlightColor(HighlightColor.purple, theme),
        const Color(0xFFD1BAE8),
      );
    });

    test('uses low-glare colors for dark reader themes', () {
      final theme = ReaderThemePreset.night.data;

      expect(
        readerHighlightColor(HighlightColor.yellow, theme),
        const Color(0xFF63551D),
      );
      expect(
        readerHighlightColor(HighlightColor.green, theme),
        const Color(0xFF284838),
      );
      expect(
        readerHighlightColor(HighlightColor.blue, theme),
        const Color(0xFF294056),
      );
      expect(
        readerHighlightColor(HighlightColor.pink, theme),
        const Color(0xFF642B3E),
      );
      expect(
        readerHighlightColor(HighlightColor.purple, theme),
        const Color(0xFF472B64),
      );
    });
  });

  test('highlights are more opaque on light reader themes', () {
    expect(readerHighlightOpacity(ReaderThemePreset.paper.data), 0.82);
    expect(readerHighlightOpacity(ReaderThemePreset.night.data), 0.72);
  });
}
