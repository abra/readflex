import 'package:component_library/component_library.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:pagecraft/pagecraft.dart';
import 'package:preferences_service/preferences_service.dart';

import 'book_custom_css.dart';
import 'reader_device_font_scale.dart';

/// The reader's style for text pagecraft lays out, on top of the book's own
/// CSS.
BookStyle readerBookStyle(
  BuildContext context, {
  required ReaderAppearancePreferences appearance,
  required ReaderThemeData theme,
}) {
  final layout = BookLayoutPreset.fromId(appearance.layoutId).data;
  final font = ReaderFontPreset.fromId(appearance.fontId);
  final fontScale = layout.fontSize * readerPageDeviceFontScale(context);
  return BookStyle(
    fontScale: fontScale,
    fontFamily: font.fontFamily,
    fontWeight: layout.fontWeight.round(),
    letterSpacing: layout.letterSpacing,
    lineHeight: appearance.lineHeight,
    paragraphSpacing: layout.paragraphSpacing,
    textIndent: layout.textIndent,
    textColor: theme.primaryTextColor.toARGB32(),
    backgroundColor: theme.backgroundColor.toARGB32(),
    justify: appearance.textAlignment == ReaderTextAlignment.justify,
    overrideFont: appearance.overrideFont,
    overrideColor: appearance.overrideColor,
    useBookLayout: appearance.useBookLayout,
    // Pages hold as many lines as the WebView reader's did: on iOS it was
    // WebKit, whose line heights are whole pixels and, under foliate-js's
    // `-webkit-line-box-contain`, never shorter than the glyphs.
    wholePixelLineHeights: readerUsesWebKitLines,
    glyphLineBoxes: readerUsesWebKitLines,
    // The WebView reader's limits: WebKit-only properties, so Android
    // hyphenated with Chromium's defaults.
    hyphenate: layout.hyphenate,
    hyphenateLimitBefore: readerUsesWebKitLines ? 3 : 2,
    hyphenateLimitLines: readerUsesWebKitLines ? 2 : null,
    // Text size, headings, quotes, code and link colours.
    readerStyleSheet: buildBookCustomCSS(
      theme: theme,
      sizes: BookCustomCssSizes(
        rootFontSize: 16 * fontScale,
        textScale: appearance.textScale,
        lineHeight: appearance.lineHeight,
      ),
    ),
    media: readerMediaEnvironment(context),
  );
}

/// The window the book's media queries and viewport units see: the
/// reader's, on this screen, in the system's colour scheme.
CssMediaEnvironment readerMediaEnvironment(BuildContext context) {
  final window = MediaQuery.sizeOf(context);
  final display = View.maybeOf(context)?.display;
  final screen = display == null || display.size.isEmpty
      ? window
      : display.size / display.devicePixelRatio;
  return CssMediaEnvironment(
    viewportWidth: window.width,
    viewportHeight: window.height,
    deviceWidth: screen.width,
    deviceHeight: screen.height,
    devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    darkColorScheme:
        MediaQuery.platformBrightnessOf(context) == Brightness.dark,
    reducedMotion: context.reduceMotion,
  );
}

/// Whether the WebView reader on this platform was WebKit's, whose lines
/// the pages keep.
bool get readerUsesWebKitLines =>
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.macOS;

double readerPageDeviceFontScale(BuildContext context) => readerDeviceFontScale(
  platform: defaultTargetPlatform,
  viewportSize: MediaQuery.sizeOf(context),
);

/// CSS generics resolve to the app's bundled faces; symbols come from the
/// symbol font; [ink] is the reader's fonts' ink, for WebKit's line
/// boxes.
BookFonts readerBookFonts(Map<String, FontInk> ink) => BookFonts(
  serif: AppTypography.fontFamilySerif,
  sansSerif: AppTypography.fontFamilyOpenSans,
  monospace: defaultTargetPlatform == TargetPlatform.iOS
      ? 'Menlo'
      : 'monospace',
  fallback: const [AppTypography.fontFamilySymbols],
  ink: ink,
);
