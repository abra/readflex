import 'package:flutter_test/flutter_test.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:reader/src/reader_appearance_cubit.dart';
import 'package:reader/src/reader_layout_presets.dart';

void main() {
  group('ReaderLineSpacingPreset', () {
    test('Normal is the default; Compact and Relaxed are symmetric', () {
      expect(ReaderLineSpacingPreset.values, [
        ReaderLineSpacingPreset.compact,
        ReaderLineSpacingPreset.normal,
        ReaderLineSpacingPreset.relaxed,
      ]);
      expect(ReaderLineSpacingPreset.compact.lineHeight, 1.4);
      expect(
        ReaderLineSpacingPreset.normal.lineHeight,
        ReaderAppearancePreferences.defaults.lineHeight,
      );
      expect(ReaderLineSpacingPreset.relaxed.lineHeight, 1.8);
      expect(
        ReaderLineSpacingPreset.normal.lineHeight -
            ReaderLineSpacingPreset.compact.lineHeight,
        closeTo(
          ReaderLineSpacingPreset.relaxed.lineHeight -
              ReaderLineSpacingPreset.normal.lineHeight,
          1e-9,
        ),
      );
    });

    test('values are stored presets that survive normalization', () {
      for (final preset in ReaderLineSpacingPreset.values) {
        expect(
          ReaderAppearanceCubit.lineHeightPresets,
          contains(preset.lineHeight),
        );
        expect(
          ReaderAppearancePreferences.normalizeLineHeight(preset.lineHeight),
          preset.lineHeight,
        );
      }
    });

    test('nearest maps exact, below, between and above values', () {
      final cases = {
        1.4: ReaderLineSpacingPreset.compact,
        1.6: ReaderLineSpacingPreset.normal,
        1.8: ReaderLineSpacingPreset.relaxed,
        // Below and above the presets.
        1.0: ReaderLineSpacingPreset.compact,
        1.2: ReaderLineSpacingPreset.compact,
        2.0: ReaderLineSpacingPreset.relaxed,
        2.4: ReaderLineSpacingPreset.relaxed,
        // Between presets.
        1.45: ReaderLineSpacingPreset.compact,
        1.55: ReaderLineSpacingPreset.normal,
        1.65: ReaderLineSpacingPreset.normal,
        1.75: ReaderLineSpacingPreset.relaxed,
      };
      for (final entry in cases.entries) {
        expect(
          ReaderLineSpacingPreset.nearest(entry.key),
          entry.value,
          reason: '${entry.key}',
        );
      }
    });

    test('a midpoint is a tie and resolves to Normal', () {
      expect(
        ReaderLineSpacingPreset.nearest(1.5),
        ReaderLineSpacingPreset.normal,
      );
      expect(
        ReaderLineSpacingPreset.nearest(1.7),
        ReaderLineSpacingPreset.normal,
      );
      // Stepper arithmetic lands a float-noise hair closer to Relaxed; it is
      // still a midpoint.
      const drifted = 1.6 + 0.1;
      expect((drifted - 1.8).abs(), lessThan((drifted - 1.6).abs()));
      expect(
        ReaderLineSpacingPreset.nearest(drifted),
        ReaderLineSpacingPreset.normal,
      );
    });
  });

  group('ReaderMarginPreset', () {
    test('Medium is the default; Narrow and Wide are symmetric in range', () {
      expect(ReaderMarginPreset.values, [
        ReaderMarginPreset.narrow,
        ReaderMarginPreset.medium,
        ReaderMarginPreset.wide,
      ]);
      expect(ReaderMarginPreset.narrow.sideMargin, 4);
      expect(
        ReaderMarginPreset.medium.sideMargin,
        ReaderAppearancePreferences.defaults.sideMargin,
      );
      expect(ReaderMarginPreset.wide.sideMargin, 12);
      expect(
        ReaderMarginPreset.medium.sideMargin -
            ReaderMarginPreset.narrow.sideMargin,
        ReaderMarginPreset.wide.sideMargin -
            ReaderMarginPreset.medium.sideMargin,
      );
      for (final preset in ReaderMarginPreset.values) {
        expect(
          preset.sideMargin,
          inInclusiveRange(
            ReaderAppearanceCubit.minSideMargin,
            ReaderAppearanceCubit.maxSideMargin,
          ),
        );
      }
    });

    test('nearest maps exact, below, between and above values', () {
      final cases = {
        4.0: ReaderMarginPreset.narrow,
        8.0: ReaderMarginPreset.medium,
        12.0: ReaderMarginPreset.wide,
        ReaderAppearanceCubit.minSideMargin: ReaderMarginPreset.narrow,
        3.0: ReaderMarginPreset.narrow,
        ReaderAppearanceCubit.maxSideMargin: ReaderMarginPreset.wide,
        5.0: ReaderMarginPreset.narrow,
        7.0: ReaderMarginPreset.medium,
        9.0: ReaderMarginPreset.medium,
        11.0: ReaderMarginPreset.wide,
      };
      for (final entry in cases.entries) {
        expect(
          ReaderMarginPreset.nearest(entry.key),
          entry.value,
          reason: '${entry.key}',
        );
      }
    });

    test('a midpoint is a tie and resolves to Medium', () {
      expect(ReaderMarginPreset.nearest(6), ReaderMarginPreset.medium);
      expect(ReaderMarginPreset.nearest(10), ReaderMarginPreset.medium);
    });
  });
}
