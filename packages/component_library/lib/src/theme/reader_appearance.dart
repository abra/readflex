import 'package:flutter/material.dart';

import 'app_theme_data.dart';

/// User-selectable reader surface presets.
enum ReaderThemePreset {
  paper,
  warm,
  mist,
  night
  ;

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
  geist
  ;

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
    serif => kFontFamilySerif,
    sans => kFontFamilySans,
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReaderThemeData &&
          backgroundColor == other.backgroundColor &&
          surfaceColor == other.surfaceColor &&
          panelColor == other.panelColor &&
          primaryTextColor == other.primaryTextColor &&
          secondaryTextColor == other.secondaryTextColor &&
          dividerColor == other.dividerColor &&
          accentColor == other.accentColor;

  @override
  int get hashCode => Object.hash(
    backgroundColor,
    surfaceColor,
    panelColor,
    primaryTextColor,
    secondaryTextColor,
    dividerColor,
    accentColor,
  );
}

extension ReaderThemePresetX on ReaderThemePreset {
  ReaderThemeData get data => switch (this) {
    ReaderThemePreset.paper => const ReaderThemeData(
      backgroundColor: Color(0xFFF7F1E6),
      surfaceColor: Color(0xFFFCF7EF),
      panelColor: Color(0xFFF0E7D8),
      primaryTextColor: Color(0xFF2A221B),
      secondaryTextColor: Color(0xFF76685B),
      dividerColor: Color(0xFFD9CAB4),
      accentColor: Color(0xFFB86A2D),
    ),
    ReaderThemePreset.warm => const ReaderThemeData(
      backgroundColor: Color(0xFFF3E4CF),
      surfaceColor: Color(0xFFF8EDDC),
      panelColor: Color(0xFFEAD7BA),
      primaryTextColor: Color(0xFF33261B),
      secondaryTextColor: Color(0xFF7C664F),
      dividerColor: Color(0xFFD8C0A0),
      accentColor: Color(0xFFC07A39),
    ),
    ReaderThemePreset.mist => const ReaderThemeData(
      backgroundColor: Color(0xFFF3F1EC),
      surfaceColor: Color(0xFFF9F7F3),
      panelColor: Color(0xFFEAE5DD),
      primaryTextColor: Color(0xFF292520),
      secondaryTextColor: Color(0xFF72685D),
      dividerColor: Color(0xFFDCD3C7),
      accentColor: Color(0xFF9A7A56),
    ),
    ReaderThemePreset.night => const ReaderThemeData(
      backgroundColor: Color(0xFF1D1916),
      surfaceColor: Color(0xFF25201C),
      panelColor: Color(0xFF2D2722),
      primaryTextColor: Color(0xFFF1E7D9),
      secondaryTextColor: Color(0xFFBAAD9B),
      dividerColor: Color(0xFF403730),
      accentColor: Color(0xFFD08A4A),
    ),
  };
}
