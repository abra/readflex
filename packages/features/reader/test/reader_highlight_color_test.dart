import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_highlight_color.dart';

void main() {
  group('readerHighlightCssColor', () {
    test('uses the reader theme color for each highlight option', () {
      final theme = ReaderThemePreset.paper.data;

      expect(
        readerHighlightCssColor(HighlightColor.yellow, theme),
        '#f6e7ac',
      );
      expect(
        readerHighlightCssColor(HighlightColor.green, theme),
        '#bce6d1',
      );
      expect(readerHighlightCssColor(HighlightColor.blue, theme), '#c2d9f0');
      expect(readerHighlightCssColor(HighlightColor.pink, theme), '#eab8c9');
      expect(
        readerHighlightCssColor(HighlightColor.purple, theme),
        '#d1bae8',
      );
    });

    test('uses low-glare colors for dark reader themes', () {
      final theme = ReaderThemePreset.night.data;

      expect(readerHighlightCssColor(HighlightColor.yellow, theme), '#63551d');
      expect(readerHighlightCssColor(HighlightColor.green, theme), '#284838');
      expect(readerHighlightCssColor(HighlightColor.blue, theme), '#294056');
      expect(readerHighlightCssColor(HighlightColor.pink, theme), '#642b3e');
      expect(readerHighlightCssColor(HighlightColor.purple, theme), '#472b64');
    });
  });

  group('reader highlight overlay style', () {
    test('uses multiply blending on light reader themes', () {
      final theme = ReaderThemePreset.paper.data;

      expect(readerHighlightBlendMode(theme), 'multiply');
      expect(readerHighlightOpacity(theme), 0.82);
    });

    test('uses lighten blending on dark reader themes', () {
      final theme = ReaderThemePreset.night.data;

      expect(readerHighlightBlendMode(theme), 'lighten');
      expect(readerHighlightOpacity(theme), 0.72);
    });
  });
}
