import 'package:component_library/component_library.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final theme in [AppTheme.light(), AppTheme.dark()]) {
    test(
      'selection markers have an opaque readable pair (${theme.brightness})',
      () {
        final colors = theme.colorScheme;
        expect(colors.selectionMarkerBackground.a, 1);
        expect(colors.selectionMarkerBackground, isNot(colors.error));
        final a = colors.selectionMarkerBackground.computeLuminance();
        final b = colors.selectionMarkerForeground.computeLuminance();
        expect(
          a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05),
          greaterThanOrEqualTo(4.5),
        );
      },
    );
  }
}
