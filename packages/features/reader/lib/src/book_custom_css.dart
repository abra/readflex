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
  buffer.writeln('a:link, a:visited { color: $accent !important; }');
  buffer.writeln(
    'blockquote { border-inline-start: 3px solid $divider !important; '
    'padding-inline-start: 1em !important; margin-inline: 0 !important; '
    'font-style: italic; }',
  );
  buffer.writeln(
    'code, kbd, samp { background: $panel !important; '
    'padding: 0.15em 0.35em; border-radius: 4px; '
    'font-family: ui-monospace, Menlo, monospace !important; }',
  );
  buffer.writeln(
    'pre { background: $panel !important; padding: 1em !important; '
    'border-radius: 6px; overflow-x: auto; '
    'font-family: ui-monospace, Menlo, monospace !important; }',
  );
  buffer.writeln(
    'pre code { background: transparent !important; padding: 0; }',
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
