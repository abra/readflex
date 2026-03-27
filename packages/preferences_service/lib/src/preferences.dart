import 'dart:ui' show Locale;

import 'package:flutter/material.dart' show ThemeMode;

/// Reading-specific appearance settings selected by the user.
final class ReaderAppearancePreferences {
  const ReaderAppearancePreferences({
    required this.themeId,
    required this.fontId,
    required this.textScale,
    required this.lineHeight,
  });

  final String themeId;
  final String fontId;
  final double textScale;
  final double lineHeight;

  ReaderAppearancePreferences copyWith({
    String? themeId,
    String? fontId,
    double? textScale,
    double? lineHeight,
  }) => ReaderAppearancePreferences(
    themeId: themeId ?? this.themeId,
    fontId: fontId ?? this.fontId,
    textScale: textScale ?? this.textScale,
    lineHeight: lineHeight ?? this.lineHeight,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReaderAppearancePreferences &&
          themeId == other.themeId &&
          fontId == other.fontId &&
          textScale == other.textScale &&
          lineHeight == other.lineHeight;

  @override
  int get hashCode => Object.hash(themeId, fontId, textScale, lineHeight);
}

/// Stores user preferences: theme mode, locale, onboarding and setup flags.
final class Preferences {
  const Preferences({
    this.themeMode = ThemeMode.system,
    this.locale = const Locale('en'),
    this.contentLibraryLayoutMode = 'grid',
    this.readerThemeId = 'paper',
    this.readerFontId = 'serif',
    this.readerTextScale = 1.0,
    this.readerLineHeight = 1.55,
    this.onboardingCompleted = false,
    this.hasCompletedSetup = false,
  });

  final ThemeMode themeMode;
  final Locale locale;
  final String contentLibraryLayoutMode;
  final String readerThemeId;
  final String readerFontId;
  final double readerTextScale;
  final double readerLineHeight;

  /// Whether the user has completed the onboarding flow.
  final bool onboardingCompleted;

  /// Whether the user has completed the initial setup (added first content).
  final bool hasCompletedSetup;

  ReaderAppearancePreferences get readerAppearance =>
      ReaderAppearancePreferences(
        themeId: readerThemeId,
        fontId: readerFontId,
        textScale: readerTextScale,
        lineHeight: readerLineHeight,
      );

  Preferences copyWith({
    ThemeMode? themeMode,
    Locale? locale,
    String? contentLibraryLayoutMode,
    String? readerThemeId,
    String? readerFontId,
    double? readerTextScale,
    double? readerLineHeight,
    bool? onboardingCompleted,
    bool? hasCompletedSetup,
  }) => Preferences(
    themeMode: themeMode ?? this.themeMode,
    locale: locale ?? this.locale,
    contentLibraryLayoutMode:
        contentLibraryLayoutMode ?? this.contentLibraryLayoutMode,
    readerThemeId: readerThemeId ?? this.readerThemeId,
    readerFontId: readerFontId ?? this.readerFontId,
    readerTextScale: readerTextScale ?? this.readerTextScale,
    readerLineHeight: readerLineHeight ?? this.readerLineHeight,
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
          readerTextScale == other.readerTextScale &&
          readerLineHeight == other.readerLineHeight &&
          onboardingCompleted == other.onboardingCompleted &&
          hasCompletedSetup == other.hasCompletedSetup;

  @override
  int get hashCode => Object.hash(
    themeMode,
    locale,
    contentLibraryLayoutMode,
    readerThemeId,
    readerFontId,
    readerTextScale,
    readerLineHeight,
    onboardingCompleted,
    hasCompletedSetup,
  );
}
