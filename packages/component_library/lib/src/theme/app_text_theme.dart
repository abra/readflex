import 'package:flutter/painting.dart';

/// Non-null semantic text roles shared by Material and Cupertino surfaces.
class AppTextTheme {
  const AppTextTheme({
    required this.displayLarge,
    required this.displayMedium,
    required this.displaySmall,
    required this.headlineLarge,
    required this.headlineMedium,
    required this.headlineSmall,
    required this.titleLarge,
    required this.titleMedium,
    required this.titleSmall,
    required this.bodyLarge,
    required this.bodyMedium,
    required this.bodySmall,
    required this.labelLarge,
    required this.labelMedium,
    required this.labelSmall,
  });

  final TextStyle displayLarge;
  final TextStyle displayMedium;
  final TextStyle displaySmall;
  final TextStyle headlineLarge;
  final TextStyle headlineMedium;
  final TextStyle headlineSmall;
  final TextStyle titleLarge;
  final TextStyle titleMedium;
  final TextStyle titleSmall;
  final TextStyle bodyLarge;
  final TextStyle bodyMedium;
  final TextStyle bodySmall;
  final TextStyle labelLarge;
  final TextStyle labelMedium;
  final TextStyle labelSmall;

  /// Compact count in screen headers, e.g. "12 items" next to Library.
  TextStyle get screenCounter => labelSmall.copyWith(
    fontWeight: FontWeight.w400,
  );

  /// Main title in dense source rows.
  TextStyle get sourceListTitle => titleSmall.copyWith(
    fontSize: 14,
    height: 1.25,
    fontWeight: FontWeight.w500,
  );

  /// Secondary metadata in source rows, e.g. author, format, progress.
  TextStyle get sourceMetadata => labelSmall.copyWith(
    fontSize: 11,
    fontWeight: FontWeight.w400,
  );

  /// Tiny cover-corner badge text constrained by cover artwork geometry.
  TextStyle get sourceCoverBadge => labelSmall.copyWith(
    fontSize: 8,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  /// Reader chrome metadata, e.g. chapter title and page progress.
  TextStyle get readerChromeLabel => bodySmall;

  /// Reader chrome numbers should not jitter as digits change.
  TextStyle get readerChromeNumber => readerChromeLabel.copyWith(
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  /// Uppercase micro-label used above detail sections.
  TextStyle get kicker => labelSmall.copyWith(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.2,
  );

  /// Text glyph used as an icon inside status discs.
  TextStyle get statusGlyph => titleLarge.copyWith(
    fontSize: 22,
    height: 1,
    fontWeight: FontWeight.w700,
  );
}
