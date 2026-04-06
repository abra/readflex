import 'package:flutter/material.dart';

import 'app_typography.dart';
import 'components/app_button_themes.dart';
import 'components/app_card_theme.dart';
import 'components/app_input_theme.dart';
import 'components/app_navigation_theme.dart';
import 'components/app_selection_themes.dart';
import 'extensions/app_colors_ext.dart';
import 'extensions/app_dimens_ext.dart';
import 'tokens/app_colors.dart';
import 'tokens/app_elevation.dart';
import 'tokens/app_radius.dart';
import 'tokens/app_sizes.dart';
import 'tokens/app_spacing.dart';
import 'tokens/primitive_colors.dart';

/// Central theme assembly.
///
/// Usage:
/// ```dart
/// MaterialApp(
///   theme: AppTheme.light(),
///   darkTheme: AppTheme.dark(),
/// )
/// ```
///
/// Widgets read styles via standard Flutter APIs:
/// ```dart
/// context.colors.primary
/// context.text.bodyLarge
/// context.appColors.warning
/// context.dimens.spacingLg
/// ```
class AppTheme {
  AppTheme._();

  static final ThemeData _lightCached = _buildLight();
  static final ThemeData _darkCached = _buildDark();

  static ThemeData light() => _lightCached;
  static ThemeData dark() => _darkCached;
}

// ─── Light theme ──────────────────────────────────────────────

const _lightColorsExt = AppColorsExt(
  readingSurface: PrimitiveColors.warmWhite,
  readingText: PrimitiveColors.warmText,
  highlightYellow: PrimitiveColors.highlightYellowLight,
  highlightBlue: PrimitiveColors.highlightBlueLight,
  highlightGreen: PrimitiveColors.highlightGreenLight,
  highlightPink: PrimitiveColors.highlightPinkLight,
  highlightPurple: PrimitiveColors.highlightPurpleLight,
  ratingAgain: PrimitiveColors.ratingAgainLight,
  ratingHard: PrimitiveColors.ratingHardLight,
  ratingGood: PrimitiveColors.ratingGoodLight,
  ratingEasy: PrimitiveColors.ratingEasyLight,
  warning: PrimitiveColors.warningLight,
  warningForeground: PrimitiveColors.warningFgLight,
  info: PrimitiveColors.infoLight,
  infoForeground: PrimitiveColors.infoFgLight,
  success: PrimitiveColors.successLight,
  successForeground: PrimitiveColors.successFgLight,
  proBadge: PrimitiveColors.proBadgeLight,
  proBadgeForeground: PrimitiveColors.proBadgeFgLight,
  tabActive: PrimitiveColors.gray900,
  tabInactive: PrimitiveColors.gray500,
  divider: PrimitiveColors.gray250,
  aiAccent: PrimitiveColors.purple500,
);

ThemeData _buildLight() {
  const palette = lightPalette;

  final colorScheme = ColorScheme.light(
    primary: palette.primary,
    onPrimary: palette.onPrimary,
    secondary: palette.secondary,
    onSecondary: palette.onSecondary,
    surface: palette.background,
    onSurface: palette.foreground,
    error: palette.error,
    onError: palette.onError,
    outline: palette.border,
    surfaceContainerHighest: palette.muted,
    surfaceTint: Colors.transparent,
  );

  final textTheme = AppTypography.textTheme.apply(
    fontFamily: AppTypography.fontFamilySans,
    bodyColor: palette.foreground,
    displayColor: palette.foreground,
  );

  return _assembleTheme(
    palette: palette,
    colorScheme: colorScheme,
    textTheme: textTheme,
    brightness: Brightness.light,
    colorsExt: _lightColorsExt,
  );
}

// ─── Dark theme ───────────────────────────────────────────────

const _darkColorsExt = AppColorsExt(
  readingSurface: PrimitiveColors.warmSurfaceDark,
  readingText: PrimitiveColors.warmTextDark,
  highlightYellow: PrimitiveColors.highlightYellowDark,
  highlightBlue: PrimitiveColors.highlightBlueDark,
  highlightGreen: PrimitiveColors.highlightGreenDark,
  highlightPink: PrimitiveColors.highlightPinkDark,
  highlightPurple: PrimitiveColors.highlightPurpleDark,
  ratingAgain: PrimitiveColors.ratingAgainDark,
  ratingHard: PrimitiveColors.ratingHardDark,
  ratingGood: PrimitiveColors.ratingGoodDark,
  ratingEasy: PrimitiveColors.ratingEasyDark,
  warning: PrimitiveColors.warningDark,
  warningForeground: PrimitiveColors.warningFgDark,
  info: PrimitiveColors.infoDark,
  infoForeground: PrimitiveColors.infoFgDark,
  success: PrimitiveColors.successDark,
  successForeground: PrimitiveColors.successFgDark,
  proBadge: PrimitiveColors.proBadgeDark,
  proBadgeForeground: PrimitiveColors.proBadgeFgDark,
  tabActive: PrimitiveColors.darkGray50,
  tabInactive: PrimitiveColors.darkGray500,
  divider: PrimitiveColors.darkGray700,
  aiAccent: PrimitiveColors.purple400,
);

ThemeData _buildDark() {
  const palette = darkPalette;

  final colorScheme = ColorScheme.dark(
    primary: palette.primary,
    onPrimary: palette.onPrimary,
    secondary: palette.secondary,
    onSecondary: palette.onSecondary,
    surface: palette.background,
    onSurface: palette.foreground,
    error: palette.error,
    onError: palette.onError,
    outline: palette.border,
    surfaceContainerHighest: palette.muted,
    surfaceTint: Colors.transparent,
  );

  final textTheme = AppTypography.textTheme.apply(
    fontFamily: AppTypography.fontFamilySans,
    bodyColor: palette.foreground,
    displayColor: palette.foreground,
  );

  return _assembleTheme(
    palette: palette,
    colorScheme: colorScheme,
    textTheme: textTheme,
    brightness: Brightness.dark,
    colorsExt: _darkColorsExt,
  );
}

// ─── Shared assembly ──────────────────────────────────────────

const _dimens = AppDimensExt(
  spacingXxs: AppSpacing.xxs,
  spacingXs: AppSpacing.xs,
  spacingSm: AppSpacing.sm,
  spacingMd: AppSpacing.md,
  spacingLg: AppSpacing.lg,
  spacingXl: AppSpacing.xl,
  spacingXxl: AppSpacing.xxl,
  spacingXxxl: AppSpacing.xxxl,
  spacingXxxxl: AppSpacing.xxxxl,
  radiusXs: AppRadius.xs,
  radiusSm: AppRadius.sm,
  radiusMd: AppRadius.md,
  radiusLg: AppRadius.lg,
  radiusXl: AppRadius.xl,
  radiusXxl: AppRadius.pill,
  buttonHeight: AppSizes.buttonHeight,
  inputHeight: AppSizes.inputHeight,
  iconButtonSize: AppSizes.iconButtonSize,
);

ThemeData _assembleTheme({
  required AppColorPalette palette,
  required ColorScheme colorScheme,
  required TextTheme textTheme,
  required Brightness brightness,
  required AppColorsExt colorsExt,
}) {
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: AppTypography.fontFamilySans,
    textTheme: textTheme,
    scaffoldBackgroundColor: palette.background,
    colorScheme: colorScheme,

    // --- Divider ---
    dividerTheme: DividerThemeData(
      color: palette.border,
      thickness: 0.5,
      space: 1,
    ),

    // --- Page transitions ---
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      },
    ),
    splashFactory: NoSplash.splashFactory,

    // --- AppBar ---
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: palette.background,
      foregroundColor: palette.foreground,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: AppElevation.level0,
      elevation: AppElevation.level0,
      toolbarHeight: AppSizes.appBarHeight,
      titleTextStyle: textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    ),

    // --- ListTile ---
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xs,
      ),
      iconColor: palette.mutedForeground,
      textColor: palette.foreground,
      tileColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
    ),

    // --- Components ---
    cardTheme: AppCardThemes.theme(palette),
    navigationBarTheme: AppNavigationThemes.navigationBar(palette, textTheme),
    bottomSheetTheme: AppNavigationThemes.bottomSheet(palette),
    dialogTheme: AppNavigationThemes.dialog(palette),
    filledButtonTheme: AppButtonThemes.filled(palette, textTheme),
    outlinedButtonTheme: AppButtonThemes.outlined(palette, textTheme),
    textButtonTheme: AppButtonThemes.text(palette, textTheme),
    iconButtonTheme: AppButtonThemes.icon(palette),
    inputDecorationTheme: AppInputThemes.theme(palette, textTheme),
    segmentedButtonTheme: AppSelectionThemes.segmentedButton(
      palette,
      textTheme,
    ),
    chipTheme: AppSelectionThemes.chip(palette, textTheme),

    // --- Progress ---
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: palette.primary,
      linearTrackColor: palette.muted,
      circularTrackColor: palette.muted,
    ),

    // --- Slider ---
    sliderTheme: SliderThemeData(
      trackHeight: 3,
      activeTrackColor: palette.primary,
      inactiveTrackColor: palette.muted,
      thumbColor: palette.primary,
      overlayColor: palette.primary.withValues(alpha: 0.12),
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
    ),

    // --- Extensions ---
    extensions: [colorsExt, _dimens],
  );
}
