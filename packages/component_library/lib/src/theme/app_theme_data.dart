import 'package:flutter/material.dart';

import 'nord.dart';

// M3 default sizes + 2pt, Geist typeface.
const _textTheme = TextTheme(
  displayLarge: TextStyle(fontSize: 59),
  displayMedium: TextStyle(fontSize: 47),
  displaySmall: TextStyle(fontSize: 38),
  headlineLarge: TextStyle(fontSize: 34),
  headlineMedium: TextStyle(fontSize: 30),
  headlineSmall: TextStyle(fontSize: 26),
  titleLarge: TextStyle(fontSize: 24),
  titleMedium: TextStyle(fontSize: 18),
  titleSmall: TextStyle(fontSize: 18),
  bodyLarge: TextStyle(fontSize: 18),
  bodyMedium: TextStyle(fontSize: 16),
  bodySmall: TextStyle(fontSize: 16),
  labelLarge: TextStyle(fontSize: 16),
  labelMedium: TextStyle(fontSize: 14),
  labelSmall: TextStyle(fontSize: 13),
);

/// Abstract base class describing the app's theme.
abstract class AppThemeData {
  const AppThemeData();

  /// The Material [ThemeData] passed to [MaterialApp.theme] or [MaterialApp.darkTheme].
  ThemeData get materialThemeData;
}

/// Light variant of [AppThemeData] — Nord, Frost blue accent.
final class LightAppThemeData extends AppThemeData {
  const LightAppThemeData();

  @override
  ThemeData get materialThemeData => ThemeData(
    brightness: Brightness.light,
    fontFamily: 'Geist',
    textTheme: _textTheme,
    scaffoldBackgroundColor: NordSnowStorm.nord6,
    colorScheme: const ColorScheme.light(
      primary: NordFrost.nord10,
      onPrimary: Colors.white,
      primaryContainer: NordSnowStorm.nord4,
      onPrimaryContainer: NordFrost.nord10,
      secondary: NordFrost.nord9,
      onSecondary: Colors.white,
      surface: NordSnowStorm.nord6,
      onSurface: NordPolarNight.nord0,
      onSurfaceVariant: NordPolarNight.nord3,
      outline: NordPolarNight.nord3,
      outlineVariant: NordSnowStorm.nord4,
      error: NordAurora.nord11,
      onError: Colors.white,
      surfaceContainerHighest: NordSnowStorm.nord4,
      surfaceContainerHigh: NordSnowStorm.nord4,
      surfaceContainer: NordSnowStorm.nord5,
      surfaceContainerLow: NordSnowStorm.nord5,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: NordSnowStorm.nord6,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      foregroundColor: NordPolarNight.nord0,
    ),
  );
}

/// Dark variant of [AppThemeData] — Nord, Frost blue accent.
final class DarkAppThemeData extends AppThemeData {
  const DarkAppThemeData();

  @override
  ThemeData get materialThemeData => ThemeData(
    brightness: Brightness.dark,
    fontFamily: 'Geist',
    textTheme: _textTheme,
    scaffoldBackgroundColor: NordPolarNight.nord0,
    colorScheme: const ColorScheme.dark(
      primary: NordFrost.nord9,
      onPrimary: NordPolarNight.nord0,
      primaryContainer: NordPolarNight.nord2,
      onPrimaryContainer: NordFrost.nord9,
      secondary: NordFrost.nord8,
      onSecondary: NordPolarNight.nord0,
      surface: NordPolarNight.nord0,
      onSurface: NordSnowStorm.nord6,
      onSurfaceVariant: NordSnowStorm.nord4,
      outline: NordPolarNight.nord3,
      outlineVariant: NordPolarNight.nord2,
      error: NordAurora.nord11,
      onError: NordPolarNight.nord0,
      surfaceContainerHighest: NordPolarNight.nord3,
      surfaceContainerHigh: NordPolarNight.nord2,
      surfaceContainer: NordPolarNight.nord1,
      surfaceContainerLow: NordPolarNight.nord1,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: NordPolarNight.nord0,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      foregroundColor: NordSnowStorm.nord6,
    ),
  );
}
