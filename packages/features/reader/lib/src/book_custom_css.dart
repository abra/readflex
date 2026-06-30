import 'package:component_library/component_library.dart';

import 'reader_color_utils.dart';

/// Builds unified CSS overlayed on top of foliate-js defaults and EPUB
/// publisher CSS. Controls typography scale, link/blockquote/code treatment
/// and dark-theme text normalization.
///
/// Injected via `FoliateStyle.customCSS` + `customCSSEnabled: true`.
String buildBookCustomCSS({
  required ReaderThemeData theme,
}) {
  final accent = colorToHex(theme.accentColor);
  final divider = colorToHex(theme.dividerColor);
  final panel = colorToHex(theme.panelColor);
  final primaryText = colorToHex(theme.primaryTextColor);
  final secondaryText = colorToHex(theme.secondaryTextColor);
  final isDark = theme.backgroundColor.computeLuminance() < 0.5;
  const proseFontSize = 'var(--readflex-prose-font-size, 1em)';
  const inlineCodeFontSize = 'var(--readflex-inline-code-font-size, 0.9em)';
  const kbdFontSize = 'var(--readflex-kbd-font-size, 0.85em)';
  const codeBlockFontSize = 'var(--readflex-code-block-font-size, 0.875em)';

  final buffer = StringBuffer();
  // No `text-rendering: optimizeLegibility` — it re-measures kerning when
  // web fonts finish loading, which on Android Chromium feeds back into
  // foliate-js's paginator ResizeObserver and traps layout in a loop.
  // Default `auto` already enables ligatures/kerning at body sizes.
  buffer.writeln(
    'html, body { -webkit-text-size-adjust: 100% !important; '
    'text-size-adjust: 100% !important; '
    'text-rendering: auto !important; }',
  );
  buffer.writeln(
    'body, p, li, blockquote, figcaption, div:not(.readflex-wide-table) { '
    'white-space: normal !important; overflow-wrap: anywhere !important; '
    'word-break: break-word !important; min-width: 0 !important; '
    'max-width: 100% !important; }',
  );
  buffer.writeln(
    'a, :not(pre) > code, :not(pre) > kbd, :not(pre) > samp, td, th { '
    'white-space: normal !important; overflow-wrap: anywhere !important; '
    'word-break: break-word !important; min-width: 0 !important; '
    'max-width: 100% !important; }',
  );
  buffer.writeln(
    'p:empty, span:empty, div:empty:not([class]):not([id]) { '
    'display: none !important; }',
  );
  buffer.writeln(
    'p, li, dd, dt, figcaption, caption, blockquote, font, section, article, '
    'div:not(.readflex-wide-table):not(.readflex-code-block):not(.ProgramCode)'
    ':not(.ParaTypeProgramcode):not(.LineGroup):not(.FixedLineContainer)'
    ':not(.FixedLine) { font-size: $proseFontSize !important; }',
  );
  if (isDark) {
    // In dark reader themes, readability wins over publisher colors. Keep
    // media untouched; the contrast guard still handles light inline panels.
    buffer.writeln(
      'html, body { color-scheme: dark; color: $primaryText !important; }',
    );
    buffer.writeln(
      'section, aside, article, nav, header, footer, main, figure, figcaption, '
      'caption, table, thead, tbody, tfoot, tr, td, th, div, p, font, span, '
      'h1, h2, h3, h4, h5, h6, li, dl, dt, dd, b, strong, em, i, u, s, q, '
      'cite, abbr, label, mark, pre, code, kbd, samp { '
      'color: $primaryText !important; }',
    );
    buffer.writeln(
      'blockquote, figcaption, caption, small, sup, sub { '
      'color: $secondaryText !important; }',
    );
  }
  buffer.writeln(
    'a:link, a:visited { color: $accent !important; } '
    'a, a:link, a:visited, a * { '
    'text-decoration: none !important; text-decoration-line: none !important; '
    'border-bottom: 0 !important; box-shadow: none !important; }',
  );
  buffer.writeln(
    'blockquote { border-inline-start: 3px solid $divider !important; '
    'padding-inline-start: 1em !important; margin-inline: 0 !important; '
    'text-indent: 0 !important; text-align: start !important; '
    'line-height: var(--readflex-line-height) !important; '
    'font-style: italic; }',
  );
  // Inline code: thin bordered pill, slightly smaller than prose so the
  // mono glyphs don't visually outrun surrounding serif/sans text. The
  // negative letter-spacing tightens the airy feel monospace fonts have
  // by default at small sizes.
  buffer.writeln(
    'code { background: $panel !important; border: 1px solid $divider; '
    'padding: 0.1em 0.35em; border-radius: 4px; '
    'text-indent: 0 !important; line-height: inherit !important; '
    'font-family: ui-monospace, Menlo, monospace !important; '
    'font-size: $inlineCodeFontSize !important; letter-spacing: -0.01em; }',
  );
  // <samp> = sample program output. Same shape as inline code but without
  // a border so it reads as "what the program said" rather than "source
  // you might run".
  buffer.writeln(
    'samp { background: $panel !important; '
    'padding: 0.15em 0.35em; border-radius: 4px; '
    'font-family: ui-monospace, Menlo, monospace !important; '
    'font-size: $inlineCodeFontSize !important; }',
  );
  // <kbd> = key cap. Inset bottom shadow gives a subtle raised feel so
  // a sequence like "press Cmd+K" reads as physical keys, distinct from
  // inline code that happens to be short.
  buffer.writeln(
    'kbd { background: $panel !important; border: 1px solid $divider; '
    'box-shadow: inset 0 -1px 0 $divider; '
    'padding: 0.1em 0.4em; border-radius: 4px; '
    'font-family: ui-monospace, Menlo, monospace !important; '
    'font-size: $kbdFontSize !important; font-weight: 600; }',
  );
  // Code blocks must wrap instead of becoming inner scroll containers: iOS
  // WebKit can crash or paginate into blank columns when a <pre> scrolls
  // inside foliate's column layout.
  buffer.writeln(
    'pre, .readflex-code-block, .ProgramCode, .ParaTypeProgramcode { '
    'background: $panel !important; border: 1px solid $divider; '
    'padding: 0.85em 1em !important; border-radius: 6px; '
    'display: block !important; box-sizing: border-box; '
    'width: auto !important; max-width: 100% !important; '
    'min-width: 0 !important; inline-size: auto !important; '
    'max-inline-size: 100% !important; min-inline-size: 0 !important; '
    'margin-inline: 0 !important; '
    'overflow-x: hidden !important; overflow-y: visible; '
    'break-inside: auto !important; text-indent: 0 !important; '
    'text-align: start !important; '
    'overflow-wrap: break-word !important; word-break: normal !important; '
    'font-family: ui-monospace, Menlo, monospace !important; '
    'font-size: $codeBlockFontSize !important; '
    'line-height: 1.45 !important; }',
  );
  buffer.writeln(
    'pre, .readflex-code-block, .ParaTypeProgramcode { white-space: pre-wrap !important; } '
    '.ProgramCode { white-space: normal !important; }',
  );
  // Inside a <pre>, any nested code/kbd/samp inherits the block's font
  // and styling — strip their pill/border/shadow so they don't paint a
  // box-on-box.
  buffer.writeln(
    'pre code, pre kbd, pre samp { background: transparent !important; '
    'border: 0 !important; box-shadow: none !important; '
    'padding: 0 !important; font-size: inherit !important; '
    'white-space: inherit !important; overflow-wrap: inherit !important; '
    'word-break: inherit !important; min-width: 0 !important; '
    'max-width: 100% !important; }',
  );
  buffer.writeln(
    '.readflex-code-block * { font-family: inherit !important; '
    'font-size: inherit !important; line-height: inherit !important; }',
  );
  buffer.writeln(
    '.readflex-code-block .LineGroup, .readflex-code-block .FixedLineContainer, '
    '.ProgramCode .LineGroup, .ProgramCode .FixedLineContainer { '
    'display: block !important; max-width: 100% !important; min-width: 0 !important; '
    'margin: 0 !important; white-space: normal !important; '
    'font-family: inherit !important; font-size: inherit !important; '
    'line-height: inherit !important; }',
  );
  buffer.writeln(
    '.readflex-code-block .FixedLine, .ProgramCode .FixedLine { display: block !important; '
    'max-width: 100% !important; min-width: 0 !important; margin: 0 !important; '
    'white-space: pre-wrap !important; overflow-wrap: anywhere !important; '
    'word-break: break-word !important; font-family: inherit !important; '
    'font-size: inherit !important; line-height: inherit !important; }',
  );
  buffer.writeln(
    '.readflex-code-block .LineGroup + .LineGroup, '
    '.ProgramCode .LineGroup + .LineGroup { margin-top: 0 !important; }',
  );
  // Wide tables: the JS reader wraps every table in this div on section load.
  // `overflow` on the table itself is unreliable in CSS table layout,
  // especially inside paginated WebKit columns, so the wrapper owns scroll.
  buffer.writeln(
    '.readflex-wide-table { max-width: 100%; overflow-x: auto; '
    'overflow-y: hidden; -webkit-overflow-scrolling: touch; '
    'overscroll-behavior-inline: contain; touch-action: pan-x pan-y; '
    'box-sizing: border-box; break-inside: avoid; }',
  );
  // Keep the table intrinsic width inside the scroll wrapper.
  // We deliberately omit the Readest pattern of
  // "table:has(> colgroup) { table-layout: fixed; }" because that combo
  // (the :has() selector + a forced table-layout switch) crashes
  // WKWebView's multi-column line layout (TextOnlySimpleLineBuilder
  // RELEASE_ASSERT) when foliate-js is paginating. Bisect on iOS 18.7
  // sim isolated this exact rule as the trigger.
  buffer.writeln(
    'table { width: max-content; max-width: none; display: table !important; '
    'text-indent: 0 !important; text-align: start !important; '
    'font-size: 0.95em; }',
  );
  buffer.writeln(
    'table img, table svg, table canvas { max-inline-size: 100% !important; '
    'block-size: auto !important; }',
  );
  buffer.writeln(
    'figure { margin-inline: 0 !important; break-inside: avoid; } '
    'figcaption { font-size: 0.9em; opacity: 0.75; '
    'text-align: center !important; text-indent: 0 !important; }',
  );
  buffer.writeln(
    'math, mjx-container { max-inline-size: 100%; overflow-x: auto; '
    'overflow-y: hidden; -webkit-overflow-scrolling: touch; '
    'box-sizing: border-box; }',
  );
  // Keep structural headings on the reader theme; inline emphasis still uses em/i.
  buffer.writeln(
    'h1, h2, h3, h4, h5, h6, '
    'h1 *, h2 *, h3 *, h4 *, h5 *, h6 *, '
    '[epub|type~="title"], [epub|type~="subtitle"], '
    '[role="doc-title"], [role="doc-subtitle"] { '
    'color: $primaryText !important; font-style: normal !important; }',
  );
  buffer.writeln(
    'h1 { font-size: calc($proseFontSize * 1.8) !important; }',
  );
  buffer.writeln(
    'h2 { font-size: calc($proseFontSize * 1.5) !important; }',
  );
  buffer.writeln(
    'h3 { font-size: calc($proseFontSize * 1.3) !important; }',
  );
  buffer.writeln(
    'h4, h5, h6 { font-size: calc($proseFontSize * 1.1) !important; }',
  );
  buffer.writeln(
    'h1, h2, h3, h4, h5, h6 { line-height: 1.12 !important; }',
  );
  return buffer.toString();
}
