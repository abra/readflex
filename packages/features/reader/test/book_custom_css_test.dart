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
      final css = buildBookCustomCSS(theme: lightTheme);
      expect(css, contains('a:link, a:visited'));
      expect(css, contains('#b86a2d'));
    });

    test('forces readable text colors in dark themes', () {
      final css = buildBookCustomCSS(theme: darkTheme);
      expect(
        css,
        contains(
          'html, body { color-scheme: dark; color: #f1e7d9 !important; }',
        ),
      );
      expect(css, contains('h1, h2, h3, h4, h5, h6'));
      expect(css, contains('pre, code, kbd, samp'));
      expect(css, contains('color: #f1e7d9 !important'));
      expect(css, contains('color: #baad9b !important'));
      expect(css, isNot(contains('img, canvas, svg { filter')));
    });

    test('does not force dark text normalization in light themes', () {
      final css = buildBookCustomCSS(theme: lightTheme);
      expect(css, isNot(contains('color-scheme: dark')));
      expect(css, isNot(contains('color: #2a221b !important')));
    });

    test('emits blockquote rule with divider color', () {
      final css = buildBookCustomCSS(theme: lightTheme);
      expect(css, contains('blockquote'));
      expect(css, contains('#d9cab4'));
      expect(css, contains('text-indent: 0 !important'));
      expect(css, contains('text-align: start !important'));
    });

    test('emits semantic code/pre rules with panel color', () {
      final css = buildBookCustomCSS(theme: lightTheme);
      expect(css, contains('code {'));
      expect(css, contains('kbd {'));
      expect(css, contains('samp {'));
      expect(
        css,
        contains(
          'pre, .readflex-code-block, .ProgramCode, .ParaTypeProgramcode',
        ),
      );
      expect(css, contains('#f0e7d8'));
      expect(css, contains('display: block !important'));
      expect(css, contains('white-space: pre-wrap !important'));
      expect(css, contains('.readflex-code-block'));
      expect(css, contains('.ProgramCode { white-space: normal !important; }'));
      expect(css, contains('inline-size: 100%'));
      expect(css, contains('overflow-x: hidden !important'));
      expect(css, contains('overflow-wrap: break-word !important'));
      expect(css, contains('word-break: normal !important'));
      expect(
        css,
        contains('font-size: var(--readflex-inline-code-font-size, 0.9em)'),
      );
      expect(
        css,
        contains('font-size: var(--readflex-kbd-font-size, 0.85em)'),
      );
      expect(
        css,
        contains(
          'font-size: var(--readflex-code-block-font-size, 0.875em)',
        ),
      );
      expect(css, contains('line-height: 1.45 !important'));
      expect(css, contains('break-inside: auto !important'));
      expect(css, contains('.readflex-code-block *'));
      expect(css, contains('.ProgramCode .FixedLine'));
      expect(css, contains('white-space: normal !important'));
      expect(css, contains('font-size: inherit !important'));
      expect(css, contains('margin: 0 !important'));
      expect(css, contains('.readflex-code-block .LineGroup + .LineGroup'));
    });

    test('emits safe prose wrapping and whitespace-wrapped pre blocks', () {
      final css = buildBookCustomCSS(theme: lightTheme);
      expect(css, contains('-webkit-text-size-adjust: 100% !important'));
      expect(css, contains('text-rendering: auto !important'));
      expect(css, contains('body, p, li, blockquote, figcaption'));
      expect(css, contains('var(--readflex-prose-font-size, 1em)'));
      expect(css, contains('white-space: normal !important'));
      expect(css, contains('overflow-wrap: anywhere !important'));
      expect(css, contains('word-break: break-word !important'));
      expect(css, contains('min-width: 0 !important'));
      expect(css, contains('a, :not(pre) > code, :not(pre) > kbd'));
      expect(css, contains('pre code, pre kbd, pre samp'));
      expect(css, contains('white-space: inherit !important'));
      expect(css, contains('overflow-wrap: inherit !important'));
      expect(css, contains('word-break: inherit !important'));
    });

    test('emits table and figure rules outside prose layout', () {
      final css = buildBookCustomCSS(theme: lightTheme);
      expect(css, contains('table {'));
      expect(css, contains('.readflex-wide-table'));
      expect(css, contains('touch-action: pan-x pan-y'));
      expect(css, contains('figure {'));
      expect(css, contains('figcaption {'));
      expect(css, contains('break-inside: avoid'));
    });

    test('emits wide math/media containment rules', () {
      final css = buildBookCustomCSS(theme: lightTheme);
      expect(css, contains('table img, table svg, table canvas'));
      expect(css, contains('math, mjx-container'));
      expect(css, contains('overflow-x: auto'));
    });

    test('emits heading size rules', () {
      final css = buildBookCustomCSS(theme: lightTheme);
      expect(
        css,
        contains(
          'h1 { font-size: calc(var(--readflex-prose-font-size, 1em) * 1.8) !important; }',
        ),
      );
      expect(
        css,
        contains(
          'h2 { font-size: calc(var(--readflex-prose-font-size, 1em) * 1.5) !important; }',
        ),
      );
      expect(
        css,
        contains(
          'h3 { font-size: calc(var(--readflex-prose-font-size, 1em) * 1.3) !important; }',
        ),
      );
      expect(
        css,
        contains(
          'h4, h5, h6 { font-size: calc(var(--readflex-prose-font-size, 1em) * 1.1) !important; }',
        ),
      );
      expect(
        css,
        contains('h1, h2, h3, h4, h5, h6 { line-height: 1.12 !important; }'),
      );
    });

    test('does not emit image inversion in dark themes', () {
      final css = buildBookCustomCSS(theme: darkTheme);
      expect(css, isNot(contains('filter: invert')));
    });

    test('base rules are emitted without image inversion', () {
      final css = buildBookCustomCSS(theme: lightTheme);
      expect(css, contains('a:link, a:visited'));
      expect(css, contains('blockquote'));
      expect(css, contains('code {'));
      expect(css, contains('kbd {'));
      expect(css, contains('samp {'));
      expect(css, contains('pre, .readflex-code-block'));
      expect(css, contains('h1 { font-size'));
      expect(css, isNot(contains('filter: invert')));
    });

    test('uses !important to win over publisher CSS', () {
      final css = buildBookCustomCSS(theme: lightTheme);
      expect('!important'.allMatches(css).length, greaterThan(5));
    });

    test(
      'does not emit optimizeLegibility (traps Android Chromium in a '
      'paginator ResizeObserver loop on web-font load)',
      () {
        final css = buildBookCustomCSS(theme: lightTheme);
        expect(css, isNot(contains('optimizeLegibility')));
      },
    );

    test('keeps pre descendants on the block wrapping contract', () {
      final css = buildBookCustomCSS(theme: lightTheme);
      expect(css, contains('pre code, pre kbd, pre samp'));
      expect(css, contains('white-space: inherit !important'));
      expect(css, contains('overflow-wrap: inherit !important'));
      expect(css, contains('word-break: inherit !important'));
    });
  });
}
