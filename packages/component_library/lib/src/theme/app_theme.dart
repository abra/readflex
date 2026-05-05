import 'package:flutter/material.dart';

import 'app_typography.dart';
import 'components/app_button_themes.dart';
import 'components/app_card_theme.dart';
import 'components/app_input_theme.dart';
import 'components/app_navigation_theme.dart';
import 'components/app_selection_themes.dart';
import 'extensions/app_colors_ext.dart';
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
/// ```
class AppTheme {
  AppTheme._();

  // Themes are built once and cached for the lifetime of the app. All inputs
  // to _buildLight/_buildDark are compile-time constants (token palettes,
  // typography, component themes), so the result is deterministic — there's
  // no need to rebuild on every MaterialApp rebuild. Caching here also keeps
  // ThemeData identity stable, which lets Flutter skip descendant rebuilds
  // on theme-unrelated widget tree changes.
  static final ThemeData _lightCached = _buildLight();
  static final ThemeData _darkCached = _buildDark();

  static ThemeData light() => _lightCached;

  static ThemeData dark() => _darkCached;
}

// ─── Light theme ──────────────────────────────────────────────

const _lightColorsExt = AppColorsExt(
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
  success: PrimitiveColors.successLight,
  successForeground: PrimitiveColors.successFgLight,
  proBadge: PrimitiveColors.proBadgeLight,
  proBadgeForeground: PrimitiveColors.proBadgeFgLight,
  divider: PrimitiveColors.gray250,
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
    // outlineVariant must be set explicitly. In Flutter 3.41 the
    // ColorScheme getter falls back to `onBackground` when
    // outlineVariant is omitted (`Color get outlineVariant =>
    // _outlineVariant ?? onBackground;`), and `onBackground` is the
    // light-mode foreground (≈ near-black) — so any consumer reading
    // `colorScheme.outlineVariant` (chrome dividers, slider inactive
    // track) ended up rendering solid black hairlines on a light app.
    // Pin it to the same divider colour the legacy DividerTheme uses.
    outlineVariant: palette.border,
    surfaceContainerLowest: palette.surfaceElevated,
    surfaceContainerLow: palette.card,
    surfaceContainer: palette.secondary,
    surfaceContainerHigh: palette.muted,
    surfaceContainerHighest: palette.muted,
    surfaceTint: Colors.transparent,
  );

  // NOTE: do NOT pass fontFamily to .apply() — it unconditionally
  // overwrites fontFamily on every TextStyle in the theme, wiping out
  // the serif family we set on display styles inside
  // AppTypography.textTheme. Roles without an explicit fontFamily fall
  // through to ThemeData.fontFamily (= sans) on render, which is what
  // we want for titleMedium / body / label. .apply() still applies the
  // body/display color tints correctly either way.
  final textTheme = AppTypography.textTheme.apply(
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
  success: PrimitiveColors.successDark,
  successForeground: PrimitiveColors.successFgDark,
  proBadge: PrimitiveColors.proBadgeDark,
  proBadgeForeground: PrimitiveColors.proBadgeFgDark,
  divider: PrimitiveColors.darkGray700,
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
    // Same `_outlineVariant ?? onBackground` fallback as in light mode
    // — see _buildLight for the full rationale. In dark mode the
    // missed default is the light foreground tint, which would blast
    // bright hairlines across dark chrome; pin it to the dark
    // palette's border colour instead.
    outlineVariant: palette.border,
    surfaceContainerLowest: palette.surfaceElevated,
    surfaceContainerLow: palette.card,
    surfaceContainer: palette.secondary,
    surfaceContainerHigh: palette.muted,
    surfaceContainerHighest: palette.muted,
    surfaceTint: Colors.transparent,
  );

  // NOTE: do NOT pass fontFamily to .apply() — it unconditionally
  // overwrites fontFamily on every TextStyle in the theme, wiping out
  // the serif family we set on display styles inside
  // AppTypography.textTheme. Roles without an explicit fontFamily fall
  // through to ThemeData.fontFamily (= sans) on render, which is what
  // we want for titleMedium / body / label. .apply() still applies the
  // body/display color tints correctly either way.
  final textTheme = AppTypography.textTheme.apply(
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
    extensions: [colorsExt],
  );
}
