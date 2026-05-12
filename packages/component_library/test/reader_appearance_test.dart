import 'package:component_library/component_library.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReaderFontPreset', () {
    test('fromId resolves known ids and falls back to Literata', () {
      expect(ReaderFontPreset.fromId('serif'), ReaderFontPreset.serif);
      expect(
        ReaderFontPreset.fromId('merriweather'),
        ReaderFontPreset.merriweather,
      );
      expect(ReaderFontPreset.fromId('sans'), ReaderFontPreset.sans);
      expect(ReaderFontPreset.fromId('geist'), ReaderFontPreset.geist);
      expect(ReaderFontPreset.fromId(null), ReaderFontPreset.serif);
      expect(ReaderFontPreset.fromId('unknown'), ReaderFontPreset.serif);
    });

    test('reader font options have distinct labels and font files', () {
      expect(
        ReaderFontPreset.values.map((preset) => preset.label),
        ['Literata', 'Merriweather', 'Open Sans', 'Geist'],
      );
      expect(
        ReaderFontPreset.values.map((preset) => preset.fontFile).toSet(),
        hasLength(ReaderFontPreset.values.length),
      );
    });
  });
}
