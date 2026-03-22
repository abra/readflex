import 'dart:ui' show Locale;

import 'package:flutter/material.dart' show ThemeMode;

/// Stores user preferences: theme mode, locale, onboarding and setup flags.
final class Preferences {
  const Preferences({
    this.themeMode = ThemeMode.system,
    this.locale = const Locale('en'),
    this.onboardingCompleted = false,
    this.hasCompletedSetup = false,
  });

  final ThemeMode themeMode;
  final Locale locale;

  /// Whether the user has completed the onboarding flow.
  final bool onboardingCompleted;

  /// Whether the user has completed the initial setup (added first content).
  final bool hasCompletedSetup;

  Preferences copyWith({
    ThemeMode? themeMode,
    Locale? locale,
    bool? onboardingCompleted,
    bool? hasCompletedSetup,
  }) => Preferences(
    themeMode: themeMode ?? this.themeMode,
    locale: locale ?? this.locale,
    onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    hasCompletedSetup: hasCompletedSetup ?? this.hasCompletedSetup,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Preferences &&
          themeMode == other.themeMode &&
          locale == other.locale &&
          onboardingCompleted == other.onboardingCompleted &&
          hasCompletedSetup == other.hasCompletedSetup;

  @override
  int get hashCode =>
      Object.hash(themeMode, locale, onboardingCompleted, hasCompletedSetup);
}
