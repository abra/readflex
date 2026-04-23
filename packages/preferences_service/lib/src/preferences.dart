import 'dart:ui' show Locale;

import 'package:flutter/material.dart' show ThemeMode;

/// Reader-scoped appearance slice of [Preferences] (theme / font / layout
/// IDs plus per-trait toggles). Exposed separately so widgets that only
/// care about reader look can subscribe via
/// [PreferencesScope.readerAppearanceOf] and skip rebuilds when unrelated
/// preferences change.
class ReaderAppearancePreferences {
  const ReaderAppearancePreferences({
    required this.themeId,
    required this.fontId,
    required this.layoutId,
    required this.textScale,
    required this.lineHeight,
    required this.invertImagesInDark,
    required this.overrideFont,
    required this.overrideColor,
    required this.useBookLayout,
  });

  final String themeId;
  final String fontId;
  final String layoutId;
  final double textScale;
  final double lineHeight;
  final bool invertImagesInDark;

  /// When `false`, publisher font-family / font-weight win over reader prefs.
  final bool overrideFont;

  /// When `false`, publisher text color wins over reader prefs.
  final bool overrideColor;

  /// When `false`, publisher line-height / indent / hyphenation / margins win.
  final bool useBookLayout;

  ReaderAppearancePreferences copyWith({
    String? themeId,
    String? fontId,
    String? layoutId,
    double? textScale,
    double? lineHeight,
    bool? invertImagesInDark,
    bool? overrideFont,
    bool? overrideColor,
    bool? useBookLayout,
  }) => ReaderAppearancePreferences(
    themeId: themeId ?? this.themeId,
    fontId: fontId ?? this.fontId,
    layoutId: layoutId ?? this.layoutId,
    textScale: textScale ?? this.textScale,
    lineHeight: lineHeight ?? this.lineHeight,
    invertImagesInDark: invertImagesInDark ?? this.invertImagesInDark,
    overrideFont: overrideFont ?? this.overrideFont,
    overrideColor: overrideColor ?? this.overrideColor,
    useBookLayout: useBookLayout ?? this.useBookLayout,
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
          invertImagesInDark == other.invertImagesInDark &&
          overrideFont == other.overrideFont &&
          overrideColor == other.overrideColor &&
          useBookLayout == other.useBookLayout;

  @override
  int get hashCode => Object.hash(
    themeId,
    fontId,
    layoutId,
    textScale,
    lineHeight,
    invertImagesInDark,
    overrideFont,
    overrideColor,
    useBookLayout,
  );
}

/// Immutable snapshot of every user-configurable preference in the app —
/// app theme, locale, catalog layout, reader appearance, and onboarding
/// flags. Loaded at startup, mutated via [PreferencesService.update], and
/// surfaced to widgets through [PreferencesScope].
class Preferences {
  const Preferences({
    this.themeMode = ThemeMode.system,
    this.locale = const Locale('en'),
    this.catalogLayoutMode = 'grid',
    this.readerThemeId = 'paper',
    this.readerFontId = 'serif',
    this.readerLayoutId = 'standard',
    this.readerTextScale = 1.0,
    this.readerLineHeight = 1.55,
    this.readerInvertImagesInDark = true,
    this.readerOverrideFont = true,
    this.readerOverrideColor = true,
    this.readerUseBookLayout = true,
    this.onboardingCompleted = false,
    this.hasCompletedSetup = false,
  });

  final ThemeMode themeMode;
  final Locale locale;
  final String catalogLayoutMode;
  final String readerThemeId;
  final String readerFontId;
  final String readerLayoutId;
  final double readerTextScale;
  final double readerLineHeight;
  final bool readerInvertImagesInDark;
  final bool readerOverrideFont;
  final bool readerOverrideColor;
  final bool readerUseBookLayout;

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
        overrideFont: readerOverrideFont,
        overrideColor: readerOverrideColor,
        useBookLayout: readerUseBookLayout,
      );

  Preferences copyWith({
    ThemeMode? themeMode,
    Locale? locale,
    String? catalogLayoutMode,
    String? readerThemeId,
    String? readerFontId,
    String? readerLayoutId,
    double? readerTextScale,
    double? readerLineHeight,
    bool? readerInvertImagesInDark,
    bool? readerOverrideFont,
    bool? readerOverrideColor,
    bool? readerUseBookLayout,
    bool? onboardingCompleted,
    bool? hasCompletedSetup,
  }) => Preferences(
    themeMode: themeMode ?? this.themeMode,
    locale: locale ?? this.locale,
    catalogLayoutMode: catalogLayoutMode ?? this.catalogLayoutMode,
    readerThemeId: readerThemeId ?? this.readerThemeId,
    readerFontId: readerFontId ?? this.readerFontId,
    readerLayoutId: readerLayoutId ?? this.readerLayoutId,
    readerTextScale: readerTextScale ?? this.readerTextScale,
    readerLineHeight: readerLineHeight ?? this.readerLineHeight,
    readerInvertImagesInDark:
        readerInvertImagesInDark ?? this.readerInvertImagesInDark,
    readerOverrideFont: readerOverrideFont ?? this.readerOverrideFont,
    readerOverrideColor: readerOverrideColor ?? this.readerOverrideColor,
    readerUseBookLayout: readerUseBookLayout ?? this.readerUseBookLayout,
    onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    hasCompletedSetup: hasCompletedSetup ?? this.hasCompletedSetup,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Preferences &&
          themeMode == other.themeMode &&
          locale == other.locale &&
          catalogLayoutMode == other.catalogLayoutMode &&
          readerThemeId == other.readerThemeId &&
          readerFontId == other.readerFontId &&
          readerLayoutId == other.readerLayoutId &&
          readerTextScale == other.readerTextScale &&
          readerLineHeight == other.readerLineHeight &&
          readerInvertImagesInDark == other.readerInvertImagesInDark &&
          readerOverrideFont == other.readerOverrideFont &&
          readerOverrideColor == other.readerOverrideColor &&
          readerUseBookLayout == other.readerUseBookLayout &&
          onboardingCompleted == other.onboardingCompleted &&
          hasCompletedSetup == other.hasCompletedSetup;

  @override
  int get hashCode => Object.hashAll([
    themeMode,
    locale,
    catalogLayoutMode,
    readerThemeId,
    readerFontId,
    readerLayoutId,
    readerTextScale,
    readerLineHeight,
    readerInvertImagesInDark,
    readerOverrideFont,
    readerOverrideColor,
    readerUseBookLayout,
    onboardingCompleted,
    hasCompletedSetup,
  ]);
}
