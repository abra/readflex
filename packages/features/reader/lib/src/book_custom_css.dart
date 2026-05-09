import 'package:component_library/component_library.dart';

import 'reader_color_utils.dart';

/// Builds unified CSS overlayed on top of foliate-js defaults and EPUB
/// publisher CSS. Controls typography scale, link/blockquote/code treatment
/// and dark-mode image inversion.
///
/// Injected via `FoliateStyle.customCSS` + `customCSSEnabled: true`.
String buildBookCustomCSS({
  required ReaderThemeData theme,
  required bool invertImagesInDark,
}) {
  final accent = colorToHex(theme.accentColor);
  final divider = colorToHex(theme.dividerColor);
  final panel = colorToHex(theme.panelColor);
  final isDark = theme.backgroundColor.computeLuminance() < 0.5;

  final buffer = StringBuffer();
  // No `text-rendering: optimizeLegibility` — it re-measures kerning when
  // web fonts finish loading, which on Android Chromium feeds back into
  // foliate-js's paginator ResizeObserver and traps layout in a loop.
  // Default `auto` already enables ligatures/kerning at body sizes.
  buffer.writeln(
    'body, p, li, td, th, code, pre, kbd, samp { '
    'overflow-wrap: anywhere !important; }',
  );
  buffer.writeln(
    'p:empty, span:empty, div:empty:not([class]):not([id]) { '
    'display: none !important; }',
  );
  buffer.writeln('a:link, a:visited { color: $accent !important; }');
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
    'font-size: 0.9em !important; letter-spacing: -0.01em; }',
  );
  // <samp> = sample program output. Same shape as inline code but without
  // a border so it reads as "what the program said" rather than "source
  // you might run".
  buffer.writeln(
    'samp { background: $panel !important; '
    'padding: 0.15em 0.35em; border-radius: 4px; '
    'font-family: ui-monospace, Menlo, monospace !important; '
    'font-size: 0.9em !important; }',
  );
  // <kbd> = key cap. Inset bottom shadow gives a subtle raised feel so
  // a sequence like "press Cmd+K" reads as physical keys, distinct from
  // inline code that happens to be short.
  buffer.writeln(
    'kbd { background: $panel !important; border: 1px solid $divider; '
    'box-shadow: inset 0 -1px 0 $divider; '
    'padding: 0.1em 0.4em; border-radius: 4px; '
    'font-family: ui-monospace, Menlo, monospace !important; '
    'font-size: 0.85em !important; font-weight: 600; }',
  );
  // Code block: smaller font + tighter line-height than prose (mono looks
  // dense and refined that way), plus a contour bordered card. Custom
  // webkit scrollbar so the horizontal-scroll affordance on long lines
  // matches the theme instead of showing the platform default chrome.
  buffer.writeln(
    'pre { background: $panel !important; border: 1px solid $divider; '
    'padding: 0.85em 1em !important; border-radius: 6px; '
    'box-sizing: border-box; max-width: 100%; overflow-x: auto; '
    '-webkit-overflow-scrolling: touch; overscroll-behavior-inline: contain; '
    'break-inside: avoid; text-indent: 0 !important; '
    'text-align: start !important; white-space: pre-wrap !important; '
    'font-family: ui-monospace, Menlo, monospace !important; '
    'font-size: 0.875em !important; line-height: 1.45 !important; }',
  );
  buffer.writeln(
    'pre::-webkit-scrollbar { height: 6px; } '
    'pre::-webkit-scrollbar-track { background: transparent; } '
    'pre::-webkit-scrollbar-thumb { background: $divider; border-radius: 3px; }',
  );
  // Inside a <pre>, any nested code/kbd/samp inherits the block's font
  // and styling — strip their pill/border/shadow so they don't paint a
  // box-on-box.
  buffer.writeln(
    'pre code, pre kbd, pre samp { background: transparent !important; '
    'border: 0 !important; box-shadow: none !important; '
    'padding: 0 !important; font-size: inherit !important; }',
  );
  // Wide tables: the JS reader wraps every table in this div on section load.
  // `overflow` on the table itself is unreliable in CSS table layout,
  // especially inside paginated WebKit columns, so the wrapper owns scroll.
  buffer.writeln(
    '.readflex-wide-table { max-width: 100%; overflow-x: auto; '
    'overflow-y: hidden; -webkit-overflow-scrolling: touch; '
    'overscroll-behavior-inline: contain; box-sizing: border-box; '
    'break-inside: avoid; }',
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
  buffer.writeln('h1 { font-size: 1.8em !important; }');
  buffer.writeln('h2 { font-size: 1.5em !important; }');
  buffer.writeln('h3 { font-size: 1.3em !important; }');
  buffer.writeln('h4, h5, h6 { font-size: 1.1em !important; }');
  if (isDark && invertImagesInDark) {
    buffer.writeln(
      'img, canvas, svg { filter: invert(100%) hue-rotate(180deg) !important; }',
    );
  }
  return buffer.toString();
}
