import 'dart:ui' show Locale;

import 'package:flutter/material.dart' show ThemeMode;

/// Stores user preferences: theme mode, locale and first launch flag.
final class Preferences {
  const Preferences({
    this.themeMode = ThemeMode.system,
    this.locale = const Locale('en'),
    this.isFirstLaunch = true,
  });

  final ThemeMode themeMode;
  final Locale locale;
  final bool isFirstLaunch;

  Preferences copyWith({
    ThemeMode? themeMode,
    Locale? locale,
    bool? isFirstLaunch,
  }) => Preferences(
    themeMode: themeMode ?? this.themeMode,
    locale: locale ?? this.locale,
    isFirstLaunch: isFirstLaunch ?? this.isFirstLaunch,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Preferences &&
          themeMode == other.themeMode &&
          locale == other.locale &&
          isFirstLaunch == other.isFirstLaunch;

  @override
  int get hashCode => Object.hash(themeMode, locale, isFirstLaunch);
}
