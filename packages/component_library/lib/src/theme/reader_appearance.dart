import 'package:flutter/material.dart';

import 'app_typography.dart';
import 'tokens/primitive_colors.dart';

/// User-selectable reader surface presets.
enum ReaderThemePreset {
  snow,
  paper,
  warm,
  night,
  mist
  ;

  static ReaderThemePreset fromId(String? value) => switch (value) {
    // TODO: Remove the legacy `white` alias after pre-Snow reader preferences
    // are no longer expected in local storage.
    'snow' || 'white' => snow,
    'warm' => warm,
    'mist' => mist,
    'night' => night,
    _ => paper,
  };

  String get id => name;

  String get label => switch (this) {
    snow => 'Snow',
    paper => 'Paper',
    warm => 'Warm',
    mist => 'Graphite',
    night => 'Night',
  };
}

/// User-selectable reader font presets.
enum ReaderFontPreset {
  serif,
  ptSerif,
  sans,
  geist
  ;

  static ReaderFontPreset fromId(String? value) => switch (value) {
    'ptSerif' || 'merriweather' => ptSerif,
    'sans' => sans,
    'geist' => geist,
    _ => serif,
  };

  String get id => name;

  String get label => switch (this) {
    serif => 'Literata',
    ptSerif => 'PT Serif',
    sans => 'Open Sans',
    geist => 'Geist',
  };

  String get fontFamily => switch (this) {
    serif => AppTypography.fontFamilySerif,
    ptSerif => AppTypography.fontFamilyPtSerif,
    sans => AppTypography.fontFamilyOpenSans,
    geist => AppTypography.fontFamilySans,
  };

  /// File name (under the reader server's `assets/fonts/` route) of the
  /// TTF that backs [fontFamily]. The reader screen builds a localhost
  /// URL from this so foliate-js's `@font-face` can actually load the
  /// font — Flutter's bundled fonts are invisible to the WebView, so the
  /// reader has to serve them itself.
  String get fontFile => switch (this) {
    serif => 'Literata-Variable.ttf',
    ptSerif => 'PTSerif-Regular.ttf',
    sans => 'OpenSans-Variable.ttf',
    geist => 'Geist-Variable.ttf',
  };
}

/// Reader-specific colors detached from the app shell.
class ReaderThemeData {
  const ReaderThemeData({
    required this.backgroundColor,
    required this.surfaceColor,
    required this.panelColor,
    required this.primaryTextColor,
    required this.secondaryTextColor,
    required this.dividerColor,
    required this.accentColor,
    required this.highlightYellow,
    required this.highlightGreen,
    required this.highlightBlue,
    required this.highlightPink,
    required this.highlightPurple,
  });

  final Color backgroundColor;
  final Color surfaceColor;
  final Color panelColor;
  final Color primaryTextColor;
  final Color secondaryTextColor;
  final Color dividerColor;
  final Color accentColor;
  final Color highlightYellow;
  final Color highlightGreen;
  final Color highlightBlue;
  final Color highlightPink;
  final Color highlightPurple;

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
          accentColor == other.accentColor &&
          highlightYellow == other.highlightYellow &&
          highlightGreen == other.highlightGreen &&
          highlightBlue == other.highlightBlue &&
          highlightPink == other.highlightPink &&
          highlightPurple == other.highlightPurple;

  @override
  int get hashCode => Object.hash(
    backgroundColor,
    surfaceColor,
    panelColor,
    primaryTextColor,
    secondaryTextColor,
    dividerColor,
    accentColor,
    highlightYellow,
    highlightGreen,
    highlightBlue,
    highlightPink,
    highlightPurple,
  );
}

extension ReaderThemePresetX on ReaderThemePreset {
  ReaderThemeData get data => switch (this) {
    ReaderThemePreset.snow => const ReaderThemeData(
      backgroundColor: PrimitiveColors.white,
      surfaceColor: Color(0xFFF8F9FA),
      panelColor: Color(0xFFF1F3F4),
      primaryTextColor: Color(0xFF242424),
      secondaryTextColor: Color(0xFF666A70),
      dividerColor: Color(0xFFE1E3E6),
      accentColor: Color(0xFF7A1F2B),
      highlightYellow: PrimitiveColors.highlightYellowLight,
      highlightGreen: PrimitiveColors.highlightGreenLight,
      highlightBlue: PrimitiveColors.highlightBlueLight,
      highlightPink: PrimitiveColors.highlightPinkLight,
      highlightPurple: PrimitiveColors.highlightPurpleLight,
    ),
    ReaderThemePreset.paper => const ReaderThemeData(
      backgroundColor: Color(0xFFFAF8F4),
      surfaceColor: Color(0xFFFFFFFF),
      panelColor: Color(0xFFF0EDE6),
      primaryTextColor: Color(0xFF2A2723),
      secondaryTextColor: Color(0xFF6B655E),
      dividerColor: Color(0xFFE5E1D9),
      accentColor: Color(0xFFB85A2A),
      highlightYellow: PrimitiveColors.highlightYellowLight,
      highlightGreen: PrimitiveColors.highlightGreenLight,
      highlightBlue: PrimitiveColors.highlightBlueLight,
      highlightPink: PrimitiveColors.highlightPinkLight,
      highlightPurple: PrimitiveColors.highlightPurpleLight,
    ),
    ReaderThemePreset.warm => const ReaderThemeData(
      backgroundColor: Color(0xFFF3E4CF),
      surfaceColor: Color(0xFFF8EDDC),
      panelColor: Color(0xFFEAD7BA),
      primaryTextColor: Color(0xFF33261B),
      secondaryTextColor: Color(0xFF7C664F),
      dividerColor: Color(0xFFD8C0A0),
      accentColor: Color(0xFFC07A39),
      highlightYellow: PrimitiveColors.highlightYellowLight,
      highlightGreen: PrimitiveColors.highlightGreenLight,
      highlightBlue: PrimitiveColors.highlightBlueLight,
      highlightPink: PrimitiveColors.highlightPinkLight,
      highlightPurple: PrimitiveColors.highlightPurpleLight,
    ),
    ReaderThemePreset.mist => const ReaderThemeData(
      backgroundColor: Color(0xFF0F1115),
      surfaceColor: Color(0xFF171A20),
      panelColor: Color(0xFF1E222A),
      primaryTextColor: Color(0xFFBCC1CA),
      secondaryTextColor: Color(0xFF9299A6),
      dividerColor: Color(0xFF2A2F38),
      accentColor: Color(0xFF9AA4B2),
      highlightYellow: PrimitiveColors.highlightYellowDark,
      highlightGreen: PrimitiveColors.highlightGreenDark,
      highlightBlue: PrimitiveColors.highlightBlueDark,
      highlightPink: PrimitiveColors.highlightPinkDark,
      highlightPurple: PrimitiveColors.highlightPurpleDark,
    ),
    ReaderThemePreset.night => const ReaderThemeData(
      backgroundColor: Color(0xFF242830),
      surfaceColor: Color(0xFF4A5456),
      panelColor: Color(0xFF354044),
      primaryTextColor: Color(0xFFABB2BF),
      secondaryTextColor: Color(0xFFB5C0C2),
      dividerColor: Color(0xFF5A6466),
      accentColor: Color(0xFFD08A4A),
      highlightYellow: PrimitiveColors.highlightYellowDark,
      highlightGreen: PrimitiveColors.highlightGreenDark,
      highlightBlue: PrimitiveColors.highlightBlueDark,
      highlightPink: PrimitiveColors.highlightPinkDark,
      highlightPurple: PrimitiveColors.highlightPurpleDark,
    ),
  };
}
