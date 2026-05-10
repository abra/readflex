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
      expect(css, contains('text-indent: 0 !important'));
      expect(css, contains('text-align: start !important'));
    });

    test('emits semantic code/pre rules with panel color', () {
      final css = buildBookCustomCSS(
        theme: lightTheme,
        invertImagesInDark: true,
      );
      expect(css, contains('code {'));
      expect(css, contains('kbd {'));
      expect(css, contains('samp {'));
      expect(css, contains('pre {'));
      expect(css, contains('#f0e7d8'));
      expect(css, contains('white-space: pre-wrap !important'));
      expect(css, contains('line-height: 1.45 !important'));
      expect(css, contains('-webkit-overflow-scrolling: touch'));
      expect(css, contains('overscroll-behavior-inline: contain'));
    });

    test(
      'emits safe word wrapping without forcing pre blocks to wrap tokens',
      () {
        final css = buildBookCustomCSS(
          theme: lightTheme,
          invertImagesInDark: true,
        );
        expect(css, contains('-webkit-text-size-adjust: 100% !important'));
        expect(css, contains('body, p, li, blockquote, figcaption'));
        expect(css, contains('white-space: normal !important'));
        expect(css, contains('overflow-wrap: anywhere !important'));
        expect(css, contains('word-break: break-word !important'));
        expect(css, contains('min-width: 0 !important'));
        expect(css, contains('a, code, kbd, samp, td, th'));
        expect(css, contains('overflow-wrap: normal !important'));
        expect(css, contains('white-space: inherit !important'));
      },
    );

    test('emits table and figure rules outside prose layout', () {
      final css = buildBookCustomCSS(
        theme: lightTheme,
        invertImagesInDark: true,
      );
      expect(css, contains('table {'));
      expect(css, contains('.readflex-wide-table'));
      expect(css, contains('figure {'));
      expect(css, contains('figcaption {'));
      expect(css, contains('break-inside: avoid'));
    });

    test('emits wide math/media containment rules', () {
      final css = buildBookCustomCSS(
        theme: lightTheme,
        invertImagesInDark: true,
      );
      expect(css, contains('table img, table svg, table canvas'));
      expect(css, contains('math, mjx-container'));
      expect(css, contains('overflow-x: auto'));
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

    test('keeps word-break reset for pre descendants', () {
      final css = buildBookCustomCSS(
        theme: lightTheme,
        invertImagesInDark: true,
      );
      expect(css, contains('pre code, pre kbd, pre samp'));
      expect(css, contains('word-break: normal !important'));
    });
  });
}
