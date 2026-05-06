import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/book_custom_css.dart';

void main() {
  group('buildBookCustomCSS', () {
    const lightTheme = ReaderThemeData(
      backgroundColor: Color(0xFFF7F1E6),
      surfaceColor: Color(0xFFFCF7EF),
      panelColor: Color(0xFFF0E7D8),
      primaryTextColor: Color(0xFF2A221B),
      secondaryTextColor: Color(0xFF76685B),
      dividerColor: Color(0xFFD9CAB4),
      accentColor: Color(0xFFB86A2D),
    );

    const darkTheme = ReaderThemeData(
      backgroundColor: Color(0xFF1D1916),
      surfaceColor: Color(0xFF25201C),
      panelColor: Color(0xFF2D2722),
      primaryTextColor: Color(0xFFF1E7D9),
      secondaryTextColor: Color(0xFFBAAD9B),
      dividerColor: Color(0xFF403730),
      accentColor: Color(0xFFD08A4A),
    );

    test('emits accent link color from theme', () {
      final css = buildBookCustomCSS(
        theme: lightTheme,
        invertImagesInDark: true,
      );
      expect(css, contains('a:link, a:visited'));
      expect(css, contains('#b86a2d'));
    });

    test('emits blockquote rule with divider color', () {
      final css = buildBookCustomCSS(
        theme: lightTheme,
        invertImagesInDark: true,
      );
      expect(css, contains('blockquote'));
      expect(css, contains('#d9cab4'));
    });

    test('emits code/pre rules with panel color', () {
      final css = buildBookCustomCSS(
        theme: lightTheme,
        invertImagesInDark: true,
      );
      expect(css, contains('code {'));
      expect(css, contains('kbd {'));
      expect(css, contains('samp {'));
      expect(css, contains('pre {'));
      expect(css, contains('#f0e7d8'));
    });

    test('emits heading size rules', () {
      final css = buildBookCustomCSS(
        theme: lightTheme,
        invertImagesInDark: true,
      );
      expect(css, contains('h1 { font-size: 1.8em !important; }'));
      expect(css, contains('h2 { font-size: 1.5em !important; }'));
      expect(css, contains('h3 { font-size: 1.3em !important; }'));
      expect(css, contains('h4, h5, h6 { font-size: 1.1em !important; }'));
    });

    test('includes image invert filter when dark theme and flag enabled', () {
      final css = buildBookCustomCSS(
        theme: darkTheme,
        invertImagesInDark: true,
      );
      expect(css, contains('img, canvas, svg'));
      expect(css, contains('filter: invert(100%) hue-rotate(180deg)'));
    });

    test('omits image invert filter when dark theme but flag disabled', () {
      final css = buildBookCustomCSS(
        theme: darkTheme,
        invertImagesInDark: false,
      );
      expect(css, isNot(contains('filter: invert')));
    });

    test(
      'omits image invert filter for light theme even with flag enabled',
      () {
        final css = buildBookCustomCSS(
          theme: lightTheme,
          invertImagesInDark: true,
        );
        expect(css, isNot(contains('filter: invert')));
      },
    );

    test('base rules emitted regardless of invert flag', () {
      final cssOn = buildBookCustomCSS(
        theme: lightTheme,
        invertImagesInDark: true,
      );
      final cssOff = buildBookCustomCSS(
        theme: lightTheme,
        invertImagesInDark: false,
      );
      for (final css in [cssOn, cssOff]) {
        expect(css, contains('a:link, a:visited'));
        expect(css, contains('blockquote'));
        expect(css, contains('code {'));
        expect(css, contains('kbd {'));
        expect(css, contains('samp {'));
        expect(css, contains('pre {'));
        expect(css, contains('h1 { font-size'));
      }
    });

    test('uses !important to win over publisher CSS', () {
      final css = buildBookCustomCSS(
        theme: lightTheme,
        invertImagesInDark: true,
      );
      expect('!important'.allMatches(css).length, greaterThan(5));
    });

    test(
      'does not emit optimizeLegibility (traps Android Chromium in a '
      'paginator ResizeObserver loop on web-font load)',
      () {
        final css = buildBookCustomCSS(
          theme: lightTheme,
          invertImagesInDark: true,
        );
        expect(css, isNot(contains('optimizeLegibility')));
      },
    );

    test('does not emit deprecated word-break: break-word alias', () {
      final css = buildBookCustomCSS(
        theme: lightTheme,
        invertImagesInDark: true,
      );
      expect(css, isNot(contains('word-break')));
    });
  });
}
