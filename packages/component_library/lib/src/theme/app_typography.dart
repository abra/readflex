import 'package:flutter/material.dart';

/// App typography system.
///
/// [textTheme] defines all text roles. Display/headline styles use Literata
/// for a warm literary feel; title/body/label use Geist for
/// clean UI readability — Geist has a narrower advance width than Inter,
/// which fits longer titles in compact surfaces (e.g. library grid
/// covers) without losing legibility on Cyrillic and Latin.
///
/// App chrome uses Geist for dense UI text and Literata for literary headings.
/// Reader-specific font choices live in [ReaderFontPreset].
abstract final class AppTypography {
  static const String fontFamilySans = 'Geist';
  static const String fontFamilySerif = 'Literata';
  static const String fontFamilyMerriweather = 'Merriweather';
  static const String fontFamilyOpenSans = 'Open Sans';

  static const TextTheme textTheme = TextTheme(
    displayLarge: TextStyle(
      fontFamily: fontFamilySerif,
      fontSize: 52,
      height: 1.04,
      fontWeight: FontWeight.w600,
    ),
    displayMedium: TextStyle(
      fontFamily: fontFamilySerif,
      fontSize: 44,
      height: 1.06,
      fontWeight: FontWeight.w600,
    ),
    displaySmall: TextStyle(
      fontFamily: fontFamilySerif,
      fontSize: 36,
      height: 1.08,
      fontWeight: FontWeight.w600,
    ),
    // Screen titles (Library, Dictionary, Profile, etc.) use these
    // roles. Serif fits a content-first reader app — same family as
    // book covers / chapter titles in Apple Books, Libby, Kobo. Sans
    // is reserved for `title*` (smaller in-screen section headers)
    // and `body*` / `label*` where density wins over character.
    headlineLarge: TextStyle(
      fontFamily: fontFamilySerif,
      fontSize: 32,
      height: 1.12,
      fontWeight: FontWeight.w600,
    ),
    headlineMedium: TextStyle(
      fontFamily: fontFamilySerif,
      fontSize: 28,
      height: 1.16,
      fontWeight: FontWeight.w600,
    ),
    headlineSmall: TextStyle(
      fontFamily: fontFamilySerif,
      fontSize: 24,
      height: 1.2,
      fontWeight: FontWeight.w600,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      height: 1.24,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: TextStyle(
      fontSize: 17,
      height: 1.28,
      fontWeight: FontWeight.w600,
    ),
    titleSmall: TextStyle(
      fontSize: 15,
      height: 1.3,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: TextStyle(
      fontSize: 17,
      height: 1.45,
      fontWeight: FontWeight.w400,
    ),
    bodyMedium: TextStyle(
      fontSize: 15,
      height: 1.45,
      fontWeight: FontWeight.w400,
    ),
    bodySmall: TextStyle(
      fontSize: 13,
      height: 1.4,
      fontWeight: FontWeight.w400,
    ),
    labelLarge: TextStyle(
      fontSize: 15,
      height: 1.2,
      fontWeight: FontWeight.w600,
    ),
    labelMedium: TextStyle(
      fontSize: 13,
      height: 1.2,
      fontWeight: FontWeight.w600,
    ),
    labelSmall: TextStyle(
      fontSize: 12,
      height: 1.2,
      fontWeight: FontWeight.w600,
    ),
  );

  static TextStyle serif({
    TextStyle? textStyle,
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
  }) => (textStyle ?? const TextStyle()).copyWith(
    color: color,
    fontSize: fontSize,
    fontWeight: fontWeight,
    fontStyle: fontStyle,
    letterSpacing: letterSpacing,
    height: height,
    decoration: decoration,
    fontFamily: fontFamilySerif,
  );

  static TextStyle sans({
    TextStyle? textStyle,
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
  }) => (textStyle ?? const TextStyle()).copyWith(
    color: color,
    fontSize: fontSize,
    fontWeight: fontWeight,
    fontStyle: fontStyle,
    letterSpacing: letterSpacing,
    height: height,
    decoration: decoration,
    fontFamily: fontFamilySans,
  );
}
