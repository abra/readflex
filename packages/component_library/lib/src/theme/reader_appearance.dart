import 'package:flutter/material.dart';

/// User-selectable reader surface presets.
enum ReaderThemePreset {
  paper,
  warm,
  mist,
  night;

  static ReaderThemePreset fromId(String? value) => switch (value) {
    'warm' => warm,
    'mist' => mist,
    'night' => night,
    _ => paper,
  };

  String get id => name;

  String get label => switch (this) {
    paper => 'Paper',
    warm => 'Warm',
    mist => 'Mist',
    night => 'Night',
  };
}

/// User-selectable reader font presets.
enum ReaderFontPreset {
  serif,
  sans,
  geist;

  static ReaderFontPreset fromId(String? value) => switch (value) {
    'sans' => sans,
    'geist' => geist,
    _ => serif,
  };

  String get id => name;

  String get label => switch (this) {
    serif => 'Serif',
    sans => 'Sans',
    geist => 'Geist',
  };

  String get fontFamily => switch (this) {
    serif => 'serif',
    sans => 'sans-serif',
    geist => 'Geist',
  };
}

/// Reader-specific colors detached from the app shell.
final class ReaderThemeData {
  const ReaderThemeData({
    required this.backgroundColor,
    required this.surfaceColor,
    required this.panelColor,
    required this.primaryTextColor,
    required this.secondaryTextColor,
    required this.dividerColor,
    required this.accentColor,
  });

  final Color backgroundColor;
  final Color surfaceColor;
  final Color panelColor;
  final Color primaryTextColor;
  final Color secondaryTextColor;
  final Color dividerColor;
  final Color accentColor;
}

extension ReaderThemePresetX on ReaderThemePreset {
  ReaderThemeData get data => switch (this) {
    ReaderThemePreset.paper => const ReaderThemeData(
      backgroundColor: Color(0xFFF6F1E7),
      surfaceColor: Color(0xFFFFFCF6),
      panelColor: Color(0xFFF0E8DB),
      primaryTextColor: Color(0xFF28231E),
      secondaryTextColor: Color(0xFF6E675E),
      dividerColor: Color(0xFFD9CFBE),
      accentColor: Color(0xFF6B7C8E),
    ),
    ReaderThemePreset.warm => const ReaderThemeData(
      backgroundColor: Color(0xFFF1E7D4),
      surfaceColor: Color(0xFFF9F2E4),
      panelColor: Color(0xFFE8DAC0),
      primaryTextColor: Color(0xFF2F261C),
      secondaryTextColor: Color(0xFF74614B),
      dividerColor: Color(0xFFD8C4AA),
      accentColor: Color(0xFF8B6B4A),
    ),
    ReaderThemePreset.mist => const ReaderThemeData(
      backgroundColor: Color(0xFFE9EEF2),
      surfaceColor: Color(0xFFF7F9FB),
      panelColor: Color(0xFFDEE6EB),
      primaryTextColor: Color(0xFF202930),
      secondaryTextColor: Color(0xFF5F6C74),
      dividerColor: Color(0xFFD1DADF),
      accentColor: Color(0xFF627C8F),
    ),
    ReaderThemePreset.night => const ReaderThemeData(
      backgroundColor: Color(0xFF1B1D21),
      surfaceColor: Color(0xFF23262B),
      panelColor: Color(0xFF2B3035),
      primaryTextColor: Color(0xFFF1ECE3),
      secondaryTextColor: Color(0xFFB7B1A7),
      dividerColor: Color(0xFF3A4148),
      accentColor: Color(0xFF97AFC2),
    ),
  };
}
