import 'dart:ui' show Locale;

import 'package:flutter/material.dart' show ThemeMode;

/// Reading-specific appearance settings selected by the user.
class ReaderAppearancePreferences {
  const ReaderAppearancePreferences({
    required this.themeId,
    required this.fontId,
    required this.layoutId,
    required this.textScale,
    required this.lineHeight,
    required this.invertImagesInDark,
  });

  final String themeId;
  final String fontId;
  final String layoutId;
  final double textScale;
  final double lineHeight;
  final bool invertImagesInDark;

  ReaderAppearancePreferences copyWith({
    String? themeId,
    String? fontId,
    String? layoutId,
    double? textScale,
    double? lineHeight,
    bool? invertImagesInDark,
  }) => ReaderAppearancePreferences(
    themeId: themeId ?? this.themeId,
    fontId: fontId ?? this.fontId,
    layoutId: layoutId ?? this.layoutId,
    textScale: textScale ?? this.textScale,
    lineHeight: lineHeight ?? this.lineHeight,
    invertImagesInDark: invertImagesInDark ?? this.invertImagesInDark,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReaderAppearancePreferences &&
          themeId == other.themeId &&
          fontId == other.fontId &&
          layoutId == other.layoutId &&
          textScale == other.textScale &&
          lineHeight == other.lineHeight &&
          invertImagesInDark == other.invertImagesInDark;

  @override
  int get hashCode => Object.hash(
    themeId,
    fontId,
    layoutId,
    textScale,
    lineHeight,
    invertImagesInDark,
  );
}

/// Stores user preferences: theme mode, locale, onboarding and setup flags.
class Preferences {
  const Preferences({
    this.themeMode = ThemeMode.system,
    this.locale = const Locale('en'),
    this.contentLibraryLayoutMode = 'grid',
    this.readerThemeId = 'paper',
    this.readerFontId = 'serif',
    this.readerLayoutId = 'standard',
    this.readerTextScale = 1.0,
    this.readerLineHeight = 1.55,
    this.readerInvertImagesInDark = true,
    this.onboardingCompleted = false,
    this.hasCompletedSetup = false,
  });

  final ThemeMode themeMode;
  final Locale locale;
  final String contentLibraryLayoutMode;
  final String readerThemeId;
  final String readerFontId;
  final String readerLayoutId;
  final double readerTextScale;
  final double readerLineHeight;
  final bool readerInvertImagesInDark;

  /// Whether the user has completed the onboarding flow.
  final bool onboardingCompleted;

  /// Whether the user has completed the initial setup (added first content).
  final bool hasCompletedSetup;

  ReaderAppearancePreferences get readerAppearance =>
      ReaderAppearancePreferences(
        themeId: readerThemeId,
        fontId: readerFontId,
        layoutId: readerLayoutId,
        textScale: readerTextScale,
        lineHeight: readerLineHeight,
        invertImagesInDark: readerInvertImagesInDark,
      );

  Preferences copyWith({
    ThemeMode? themeMode,
    Locale? locale,
    String? contentLibraryLayoutMode,
    String? readerThemeId,
    String? readerFontId,
    String? readerLayoutId,
    double? readerTextScale,
    double? readerLineHeight,
    bool? readerInvertImagesInDark,
    bool? onboardingCompleted,
    bool? hasCompletedSetup,
  }) => Preferences(
    themeMode: themeMode ?? this.themeMode,
    locale: locale ?? this.locale,
    contentLibraryLayoutMode:
        contentLibraryLayoutMode ?? this.contentLibraryLayoutMode,
    readerThemeId: readerThemeId ?? this.readerThemeId,
    readerFontId: readerFontId ?? this.readerFontId,
    readerLayoutId: readerLayoutId ?? this.readerLayoutId,
    readerTextScale: readerTextScale ?? this.readerTextScale,
    readerLineHeight: readerLineHeight ?? this.readerLineHeight,
    readerInvertImagesInDark:
        readerInvertImagesInDark ?? this.readerInvertImagesInDark,
    onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    hasCompletedSetup: hasCompletedSetup ?? this.hasCompletedSetup,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Preferences &&
          themeMode == other.themeMode &&
          locale == other.locale &&
          contentLibraryLayoutMode == other.contentLibraryLayoutMode &&
          readerThemeId == other.readerThemeId &&
          readerFontId == other.readerFontId &&
          readerLayoutId == other.readerLayoutId &&
          readerTextScale == other.readerTextScale &&
          readerLineHeight == other.readerLineHeight &&
          readerInvertImagesInDark == other.readerInvertImagesInDark &&
          onboardingCompleted == other.onboardingCompleted &&
          hasCompletedSetup == other.hasCompletedSetup;

  @override
  int get hashCode => Object.hashAll([
    themeMode,
    locale,
    contentLibraryLayoutMode,
    readerThemeId,
    readerFontId,
    readerLayoutId,
    readerTextScale,
    readerLineHeight,
    readerInvertImagesInDark,
    onboardingCompleted,
    hasCompletedSetup,
  ]);
}
