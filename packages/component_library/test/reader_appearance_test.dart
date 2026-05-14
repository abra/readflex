import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReaderFontPreset', () {
    test('fromId resolves known ids and falls back to Literata', () {
      expect(ReaderFontPreset.fromId('serif'), ReaderFontPreset.serif);
      expect(
        ReaderFontPreset.fromId('merriweather'),
        ReaderFontPreset.ptSerif,
      );
      expect(ReaderFontPreset.fromId('ptSerif'), ReaderFontPreset.ptSerif);
      expect(ReaderFontPreset.fromId('sans'), ReaderFontPreset.sans);
      expect(ReaderFontPreset.fromId('geist'), ReaderFontPreset.geist);
      expect(ReaderFontPreset.fromId(null), ReaderFontPreset.serif);
      expect(ReaderFontPreset.fromId('unknown'), ReaderFontPreset.serif);
    });

    test('reader font options have distinct labels and font files', () {
      expect(
        ReaderFontPreset.values.map((preset) => preset.label),
        ['Literata', 'PT Serif', 'Open Sans', 'Geist'],
      );
      expect(
        ReaderFontPreset.values.map((preset) => preset.fontFile).toSet(),
        hasLength(ReaderFontPreset.values.length),
      );
    });
  });

  group('ReaderThemePreset', () {
    test('theme options keep two light and two dark reader presets', () {
      expect(
        ReaderThemePreset.values.map((preset) => preset.label),
        ['Paper', 'Warm', 'Graphite', 'Night'],
      );
      expect(ReaderThemePreset.fromId('mist').label, 'Graphite');
    });

    test('graphite theme replaces mist with a near-black gray palette', () {
      final theme = ReaderThemePreset.mist.data;

      expect(theme.backgroundColor, const Color(0xFF0F1115));
      expect(theme.primaryTextColor, const Color(0xFFBCC1CA));
      expect(theme.accentColor, const Color(0xFF9AA4B2));
    });

    test('night theme uses neutral slate colors for low-glare reading', () {
      final theme = ReaderThemePreset.night.data;

      expect(theme.backgroundColor, const Color(0xFF242830));
      expect(theme.primaryTextColor, const Color(0xFFABB2BF));
      expect(theme.secondaryTextColor, const Color(0xFFB5C0C2));
    });
  });
}
