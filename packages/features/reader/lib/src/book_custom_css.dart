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
  buffer.writeln('html { text-rendering: optimizeLegibility !important; }');
  buffer.writeln(
    'body, p, li, td, th, code, pre, kbd, samp { '
    'word-break: break-word !important; '
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
    'font-style: italic; }',
  );
  // Inline code: thin bordered pill, slightly smaller than prose so the
  // mono glyphs don't visually outrun surrounding serif/sans text. The
  // negative letter-spacing tightens the airy feel monospace fonts have
  // by default at small sizes.
  buffer.writeln(
    'code { background: $panel !important; border: 1px solid $divider; '
    'padding: 0.1em 0.35em; border-radius: 4px; '
    'font-family: ui-monospace, Menlo, monospace !important; '
    'font-size: 0.9em; letter-spacing: -0.01em; }',
  );
  // <samp> = sample program output. Same shape as inline code but without
  // a border so it reads as "what the program said" rather than "source
  // you might run".
  buffer.writeln(
    'samp { background: $panel !important; '
    'padding: 0.15em 0.35em; border-radius: 4px; '
    'font-family: ui-monospace, Menlo, monospace !important; '
    'font-size: 0.9em; }',
  );
  // <kbd> = key cap. Inset bottom shadow gives a subtle raised feel so
  // a sequence like "press Cmd+K" reads as physical keys, distinct from
  // inline code that happens to be short.
  buffer.writeln(
    'kbd { background: $panel !important; border: 1px solid $divider; '
    'box-shadow: inset 0 -1px 0 $divider; '
    'padding: 0.1em 0.4em; border-radius: 4px; '
    'font-family: ui-monospace, Menlo, monospace !important; '
    'font-size: 0.85em; font-weight: 600; }',
  );
  // Code block: smaller font + tighter line-height than prose (mono looks
  // dense and refined that way), plus a contour bordered card. Custom
  // webkit scrollbar so the horizontal-scroll affordance on long lines
  // matches the theme instead of showing the platform default chrome.
  buffer.writeln(
    'pre { background: $panel !important; border: 1px solid $divider; '
    'padding: 0.85em 1em !important; border-radius: 6px; '
    'overflow-x: auto; '
    'font-family: ui-monospace, Menlo, monospace !important; '
    'font-size: 0.875em; line-height: 1.45; }',
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
