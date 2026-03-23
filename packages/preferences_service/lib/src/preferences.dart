import 'dart:ui' show Locale;

import 'package:flutter/material.dart' show ThemeMode;

/// Stores user preferences: theme mode, locale, onboarding and setup flags.
final class Preferences {
  const Preferences({
    this.themeMode = ThemeMode.system,
    this.locale = const Locale('en'),
    this.readerThemeId = 'paper',
    this.readerFontId = 'serif',
    this.readerTextScale = 1.0,
    this.readerLineHeight = 1.55,
    this.onboardingCompleted = false,
    this.hasCompletedSetup = false,
  });

  final ThemeMode themeMode;
  final Locale locale;
  final String readerThemeId;
  final String readerFontId;
  final double readerTextScale;
  final double readerLineHeight;

  /// Whether the user has completed the onboarding flow.
  final bool onboardingCompleted;

  /// Whether the user has completed the initial setup (added first content).
  final bool hasCompletedSetup;

  Preferences copyWith({
    ThemeMode? themeMode,
    Locale? locale,
    String? readerThemeId,
    String? readerFontId,
    double? readerTextScale,
    double? readerLineHeight,
    bool? onboardingCompleted,
    bool? hasCompletedSetup,
  }) => Preferences(
    themeMode: themeMode ?? this.themeMode,
    locale: locale ?? this.locale,
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
          readerThemeId == other.readerThemeId &&
          readerFontId == other.readerFontId &&
          readerTextScale == other.readerTextScale &&
          readerLineHeight == other.readerLineHeight &&
          onboardingCompleted == other.onboardingCompleted &&
          hasCompletedSetup == other.hasCompletedSetup;

  @override
  int get hashCode =>
      Object.hash(
        themeMode,
        locale,
        readerThemeId,
        readerFontId,
        readerTextScale,
        readerLineHeight,
        onboardingCompleted,
        hasCompletedSetup,
      );
}
