import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_highlight_color.dart';
import 'package:reader/src/reader_highlight_quote_background.dart';

void main() {
  final appThemes = {'light': AppTheme.light(), 'dark': AppTheme.dark()};

  bool isLight(ReaderThemePreset preset) =>
      preset.data.backgroundColor.computeLuminance() >= .5;

  for (final MapEntry(key: appName, value: app) in appThemes.entries) {
    final scheme = app.colorScheme;
    for (final preset in ReaderThemePreset.values) {
      for (final color in HighlightColor.values) {
        for (final (role, text) in [
          ('text', scheme.onSurface),
          ('muted', scheme.onSurfaceVariant),
        ]) {
          test('$appName app, ${preset.id} reader, $color, $role text '
              'keeps 4.5:1', () {
            final background = readerHighlightQuoteBackground(
              highlight: readerHighlightColor(color, preset.data),
              surface: scheme.surface,
              text: text,
              opacity: readerHighlightOpacity(preset.data),
            );
            expect(background.a, 1, reason: 'premixed, not translucent');
            expect(
              readerContrastRatio(text, background),
              greaterThanOrEqualTo(readerHighlightQuoteMinContrast),
            );
          });
        }
      }
    }
  }

  test('a reader theme matching the app keeps the page opacity', () {
    for (final MapEntry(key: appName, value: app) in appThemes.entries) {
      final scheme = app.colorScheme;
      final appLight = scheme.brightness == Brightness.light;
      for (final preset in ReaderThemePreset.values) {
        if (isLight(preset) != appLight) continue;
        for (final color in HighlightColor.values) {
          final highlight = readerHighlightColor(color, preset.data);
          final opacity = readerHighlightOpacity(preset.data);
          expect(
            readerHighlightQuoteBackground(
              highlight: highlight,
              surface: scheme.surface,
              text: scheme.onSurface,
              opacity: opacity,
            ),
            Color.alphaBlend(
              highlight.withValues(alpha: opacity),
              scheme.surface,
            ),
            reason: '$appName app, ${preset.id}, $color',
          );
        }
      }
    }
  });

  test('a mismatched reader theme is lightened, not dropped', () {
    final scheme = AppTheme.light().colorScheme;
    final night = ReaderThemePreset.mist.data;
    final highlight = readerHighlightColor(HighlightColor.yellow, night);
    final opacity = readerHighlightOpacity(night);
    final full = Color.alphaBlend(
      highlight.withValues(alpha: opacity),
      scheme.surface,
    );
    // The deep night-theme yellow fails on the light drawer at full opacity.
    expect(
      readerContrastRatio(scheme.onSurface, full),
      lessThan(readerHighlightQuoteMinContrast),
    );
    final background = readerHighlightQuoteBackground(
      highlight: highlight,
      surface: scheme.surface,
      text: scheme.onSurface,
      opacity: opacity,
    );
    expect(background, isNot(scheme.surface));
    expect(background, isNot(full));
    expect(
      readerContrastRatio(scheme.onSurface, background),
      greaterThanOrEqualTo(readerHighlightQuoteMinContrast),
    );
  });

  test('no tint keeps contrast for text that already fails on the surface', () {
    const surface = Color(0xFFFFFFFF);
    const text = Color(0xFFBBBBBB);
    expect(
      readerHighlightQuoteBackground(
        highlight: const Color(0xFFF6E7AC),
        surface: surface,
        text: text,
        opacity: .82,
      ),
      surface,
    );
  });

  test('contrast ratio matches the WCAG extremes', () {
    expect(
      readerContrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)),
      moreOrLessEquals(21),
    );
    expect(
      readerContrastRatio(const Color(0xFF777777), const Color(0xFF777777)),
      1,
    );
  });
}
