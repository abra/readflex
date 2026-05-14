import 'package:component_library/component_library.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_loading_indicator_style.dart';

void main() {
  group('readerLoadingIndicatorStyle', () {
    test('uses visible active and track colors for light reader themes', () {
      final theme = ReaderThemePreset.paper.data;

      expect(
        readerLoadingIndicatorColor(theme),
        theme.primaryTextColor.withValues(alpha: 0.82),
      );
      expect(
        readerLoadingIndicatorTrackColor(theme),
        theme.secondaryTextColor.withValues(alpha: 0.22),
      );
      expect(
        readerLoadingIndicatorTrackColor(theme),
        isNot(readerLoadingIndicatorColor(theme)),
      );
    });

    test('uses visible active and track colors for dark reader themes', () {
      final theme = ReaderThemePreset.night.data;

      expect(
        readerLoadingIndicatorColor(theme),
        theme.primaryTextColor.withValues(alpha: 0.82),
      );
      expect(
        readerLoadingIndicatorTrackColor(theme),
        theme.primaryTextColor.withValues(alpha: 0.18),
      );
      expect(
        readerLoadingIndicatorTrackColor(theme),
        isNot(readerLoadingIndicatorColor(theme)),
      );
    });
  });
}
