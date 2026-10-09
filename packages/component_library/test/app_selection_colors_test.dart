import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrast(Color a, Color b) {
  final first = a.computeLuminance() + .05;
  final second = b.computeLuminance() + .05;
  return first > second ? first / second : second / first;
}

void main() {
  for (final theme in [AppTheme.light(), AppTheme.dark()]) {
    final colors = theme.colorScheme;

    test(
      'selection markers have an opaque readable pair (${theme.brightness})',
      () {
        expect(colors.selectionMarkerBackground.a, 1);
        expect(colors.selectionMarkerBackground, isNot(colors.error));
        expect(
          _contrast(
            colors.selectionMarkerBackground,
            colors.selectionMarkerForeground,
          ),
          greaterThanOrEqualTo(4.5),
        );
      },
    );

    test('selected controls are a translucent accent wash, never an opaque '
        'block (${theme.brightness})', () {
      final background = colors.selectedControlBackground;
      expect(background.a, lessThan(.25));
      final accent = theme.brightness == Brightness.dark
          ? colors.primaryFixedDim
          : colors.primary;
      expect(background.withValues(alpha: 1), accent);
      expect(colors.selectedControlForeground, accent);
    });

    test('selected text stays readable on every surface it is drawn on '
        '(${theme.brightness})', () {
      for (final (name, surface) in [
        ('surface', colors.surface),
        ('surfaceContainerLowest', colors.surfaceContainerLowest),
        ('surfaceContainerLow', colors.surfaceContainerLow),
        ('surfaceContainer', colors.surfaceContainer),
      ]) {
        final fill = Color.alphaBlend(
          colors.selectedControlBackground,
          surface,
        );
        expect(
          _contrast(colors.selectedControlForeground, fill),
          greaterThanOrEqualTo(4.5),
          reason: name,
        );
      }
    });
  }

  test('the dark selection is no brighter than the light one is dark', () {
    // The old opaque pink fill was the brightest block on a dark screen.
    final dark = AppTheme.dark().colorScheme;
    final fill = Color.alphaBlend(dark.selectedControlBackground, dark.surface);
    expect(fill.computeLuminance(), lessThan(.05));
  });
}
