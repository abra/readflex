import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:material_ui/material_ui.dart';

import 'app_system_ui_overlay.dart';
import 'app_typography.dart';
import 'app_text_theme.dart';
import 'app_theme_data.dart';
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

  static final _platformThemes = <(TargetPlatform, Brightness), ThemeData>{};
  static final _semanticThemes = Expando<Map<TargetPlatform, AppThemeData>>();

  /// Platform adapters share the existing palettes and reading-content fonts.
  static ThemeData forPlatform(
    TargetPlatform platform,
    Brightness brightness,
  ) => _platformThemes.putIfAbsent((platform, brightness), () {
    final base = brightness == Brightness.dark ? _darkCached : _lightCached;
    final cupertino =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
    if (cupertino) {
      final background = _cupertinoColor(
        CupertinoColors.systemGroupedBackground,
        brightness,
      );
      final surface = _cupertinoColor(
        CupertinoColors.secondarySystemGroupedBackground,
        brightness,
      );
      final label = _cupertinoColor(CupertinoColors.label, brightness);
      // Keep the native hue with enough opacity for small app captions.
      final secondaryLabel = _cupertinoColor(
        CupertinoColors.secondaryLabel,
        brightness,
      ).withValues(alpha: .8);
      final separator = _cupertinoColor(CupertinoColors.separator, brightness);
      final fill = _cupertinoColor(
        CupertinoColors.tertiarySystemFill,
        brightness,
      );
      final colors = base.colorScheme.copyWith(
        primary: brightness == Brightness.dark
            ? base.colorScheme.primaryFixedDim
            : base.colorScheme.primary,
        onPrimary: brightness == Brightness.dark
            ? base.colorScheme.onPrimaryFixed
            : base.colorScheme.onPrimary,
        surface: background,
        onSurface: label,
        onSurfaceVariant: secondaryLabel,
        surfaceContainerLowest: surface,
        surfaceContainerLow: surface,
        surfaceContainer: surface,
        surfaceContainerHigh: fill,
        surfaceContainerHighest: fill,
        outline: _cupertinoColor(CupertinoColors.opaqueSeparator, brightness),
        outlineVariant: separator,
      );
      return base.copyWith(
        platform: platform,
        colorScheme: colors,
        scaffoldBackgroundColor: background,
        cardColor: surface,
        dividerColor: separator,
        disabledColor: _cupertinoColor(
          CupertinoColors.tertiaryLabel,
          brightness,
        ),
        textTheme: _cupertinoTextTheme(base.textTheme)
            .apply(bodyColor: label, displayColor: label),
        bottomSheetTheme: base.bottomSheetTheme.copyWith(
          backgroundColor: surface,
        ),
      );
    }
    return base.copyWith(
      platform: platform,
      textTheme: base.textTheme,
    );
  });

  static CupertinoThemeData cupertino(ThemeData adapter) {
    final data = dataFor(adapter);
    final text = data.text;
    return CupertinoThemeData(
      brightness: data.colors.brightness,
      primaryColor: data.colors.selectionMarkerBackground,
      primaryContrastingColor: data.colors.selectionMarkerForeground,
      scaffoldBackgroundColor: data.backgroundColor,
      barBackgroundColor: data.backgroundColor,
      selectionHandleColor: data.selectionHandleColor,
      textTheme: CupertinoTextThemeData(
        primaryColor: data.colors.selectionMarkerBackground,
        textStyle: text.bodyLarge,
        actionTextStyle: text.labelLarge.copyWith(
          color: data.colors.selectionMarkerBackground,
        ),
        navTitleTextStyle: text.titleMedium.copyWith(
          fontWeight: FontWeight.w600,
        ),
        navLargeTitleTextStyle: text.headlineLarge,
        navActionTextStyle: text.bodyLarge.copyWith(
          color: data.colors.selectionMarkerBackground,
        ),
        tabLabelTextStyle: text.labelSmall,
      ),
    );
  }

  /// Cache by theme identity and platform; tests may override the host platform.
  static AppThemeData dataFor(ThemeData adapter) {
    final byPlatform = _semanticThemes[adapter] ??= {};
    return byPlatform.putIfAbsent(adapter.platform, () {
      final c = adapter.colorScheme;
      final t = adapter.textTheme;
      return AppThemeData(
        platform: adapter.platform,
        colors: AppThemeColors(
          brightness: c.brightness,
          primary: c.primary,
          onPrimary: c.onPrimary,
          primaryFixedDim: c.primaryFixedDim,
          onPrimaryFixed: c.onPrimaryFixed,
          surface: c.surface,
          onSurface: c.onSurface,
          onSurfaceVariant: c.onSurfaceVariant,
          surfaceContainerLowest: c.surfaceContainerLowest,
          surfaceContainerLow: c.surfaceContainerLow,
          surfaceContainer: c.surfaceContainer,
          surfaceContainerHigh: c.surfaceContainerHigh,
          surfaceContainerHighest: c.surfaceContainerHighest,
          secondaryContainer: c.secondaryContainer,
          onSecondaryContainer: c.onSecondaryContainer,
          outline: c.outline,
          outlineVariant: c.outlineVariant,
          inverseSurface: c.inverseSurface,
          onInverseSurface: c.onInverseSurface,
          inversePrimary: c.inversePrimary,
          scrim: c.scrim,
          error: c.error,
          onError: c.onError,
          errorContainer: c.errorContainer,
          onErrorContainer: c.onErrorContainer,
        ),
        text: AppTextTheme(
          displayLarge: t.displayLarge!,
          displayMedium: t.displayMedium!,
          displaySmall: t.displaySmall!,
          headlineLarge: t.headlineLarge!,
          headlineMedium: t.headlineMedium!,
          headlineSmall: t.headlineSmall!,
          titleLarge: t.titleLarge!,
          titleMedium: t.titleMedium!,
          titleSmall: t.titleSmall!,
          bodyLarge: t.bodyLarge!,
          bodyMedium: t.bodyMedium!,
          bodySmall: t.bodySmall!,
          labelLarge: t.labelLarge!,
          labelMedium: t.labelMedium!,
          labelSmall: t.labelSmall!,
        ),
        appColors:
            adapter.extension<AppColorsExt>() ??
            (adapter.brightness == Brightness.dark
                ? _darkColorsExt
                : _lightColorsExt),
        backgroundColor: adapter.scaffoldBackgroundColor,
        sheetColor: adapter.bottomSheetTheme.backgroundColor ?? c.surface,
        selectionHandleColor:
            adapter.textSelectionTheme.selectionHandleColor ?? c.primary,
        disabledColor: adapter.disabledColor,
      );
    });
  }

  static ThemeData light() =>
      forPlatform(defaultTargetPlatform, Brightness.light);

  static ThemeData dark() =>
      forPlatform(defaultTargetPlatform, Brightness.dark);
}

// ─── Light theme ──────────────────────────────────────────────

TextTheme _cupertinoTextTheme(TextTheme source) {
  final family = const CupertinoTextThemeData().textStyle.fontFamily;
  final text = source.apply(fontFamily: family);
  return text.copyWith(
    headlineLarge: text.headlineLarge!.copyWith(
      fontSize: 34,
      height: 1.18,
      fontWeight: FontWeight.w700,
      letterSpacing: .37,
    ),
    titleLarge: text.titleLarge!.copyWith(fontSize: 22, height: 1.25),
    titleMedium: text.titleMedium!.copyWith(fontSize: 17, height: 1.3),
    bodyLarge: text.bodyLarge!.copyWith(fontSize: 17, height: 1.35),
    bodyMedium: text.bodyMedium!.copyWith(fontSize: 15, height: 1.35),
    labelLarge: text.labelLarge!.copyWith(
      fontSize: 17,
      height: 1.25,
      fontWeight: FontWeight.w500,
    ),
  );
}

Color _cupertinoColor(CupertinoDynamicColor color, Brightness brightness) =>
    brightness == Brightness.dark ? color.darkColor : color.color;

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
  successContainer: PrimitiveColors.successFgLight,
  onSuccessContainer: PrimitiveColors.white,
  successOnInverse: PrimitiveColors.successFgDark,
  errorOnInverse: PrimitiveColors.red300,
  proBadge: PrimitiveColors.proBadgeLight,
  proBadgeForeground: PrimitiveColors.proBadgeFgLight,
  divider: PrimitiveColors.gray250,
  onLightSwatch: PrimitiveColors.gray900,
  onDarkSwatch: PrimitiveColors.white,
);

ThemeData _buildLight() {
  const palette = lightPalette;

  // Material 3 idiom: build the full scheme from a seed (so every M3
  // role gets a tonally-harmonious value out of the box — no holes
  // for `outlineVariant`, `inversePrimary`, `surfaceTint`, etc. to
  // fall back to broken framework defaults), then `.copyWith` the
  // brand-specific overrides we own. Anything we don't override is
  // kept at the seed-derived value, which is already correct M3.
  final colorScheme =
      ColorScheme.fromSeed(
        seedColor: palette.primary,
        brightness: Brightness.light,
      ).copyWith(
        primary: palette.primary,
        onPrimary: palette.onPrimary,
        secondary: palette.secondary,
        onSecondary: palette.onSecondary,
        surface: palette.background,
        onSurface: palette.foreground,
        error: palette.error,
        onError: palette.onError,
        outline: palette.border,
        outlineVariant: palette.border,
        // The seed would tint muted text toward the wine accent; keep it in
        // the same cool gray family as the surfaces.
        onSurfaceVariant: palette.mutedForeground,
        // Notification plates: neutral grays, not the seed's warm inverse.
        inverseSurface: PrimitiveColors.gray900,
        onInverseSurface: PrimitiveColors.gray50,
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
  successContainer: PrimitiveColors.successFgDark,
  onSuccessContainer: PrimitiveColors.darkGray900,
  successOnInverse: PrimitiveColors.successFgLight,
  errorOnInverse: PrimitiveColors.red600,
  proBadge: PrimitiveColors.proBadgeDark,
  proBadgeForeground: PrimitiveColors.proBadgeFgDark,
  divider: PrimitiveColors.darkGray700,
  onLightSwatch: PrimitiveColors.darkGray900,
  onDarkSwatch: PrimitiveColors.white,
);

ThemeData _buildDark() {
  const palette = darkPalette;

  // Same M3-idiomatic recipe as `_buildLight`: seed the full scheme
  // from the brand primary, then `.copyWith` only the roles we own.
  // The seed handles every M3 role (outlineVariant, inversePrimary,
  // scrim, etc.) with values tonally derived from the brand colour,
  // so unspecified roles can never collapse to a broken Flutter
  // default again.
  final colorScheme =
      ColorScheme.fromSeed(
        seedColor: palette.primary,
        brightness: Brightness.dark,
      ).copyWith(
        primary: palette.primary,
        onPrimary: palette.onPrimary,
        secondary: palette.secondary,
        onSecondary: palette.onSecondary,
        surface: palette.background,
        onSurface: palette.foreground,
        error: palette.error,
        onError: palette.onError,
        outline: palette.border,
        outlineVariant: palette.border,
        // The seed would tint muted text toward the wine accent; keep it in
        // the same cool gray family as the surfaces.
        onSurfaceVariant: palette.mutedForeground,
        inverseSurface: PrimitiveColors.darkGray50,
        onInverseSurface: PrimitiveColors.darkGray900,
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
  final systemOverlayStyle = appSystemUiOverlayStyle(
    brightness: brightness,
    backgroundColor: palette.background,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: AppTypography.fontFamilySans,
    fontFamilyFallback: AppTypography.fontFamilyFallback,
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
      systemOverlayStyle: systemOverlayStyle,
      // A theme-level style is not merged with ThemeData.fontFamily, so the
      // sans family is set here, as the button themes do.
      titleTextStyle: AppTypography.sans(
        textStyle: textTheme.titleMedium,
        fontWeight: FontWeight.w600,
      ).copyWith(fontFamilyFallback: AppTypography.fontFamilyFallback),
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
      // Rectangular by default: tiles are full-bleed rows in panels and
      // sheets; a radius would bleed into their selected fill and press ink.
    ),

    // --- MenuAnchor menus share the popup radius of rows and sheets ---
    menuTheme: MenuThemeData(
      style: MenuStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      ),
    ),

    // --- Components ---
    cardTheme: AppCardThemes.theme(palette),
    navigationBarTheme: AppNavigationThemes.navigationBar(palette, textTheme),
    bottomSheetTheme: AppNavigationThemes.bottomSheet(palette),
    dialogTheme: AppNavigationThemes.dialog(palette),
    filledButtonTheme: AppButtonThemes.filled(palette, textTheme),
    outlinedButtonTheme: AppButtonThemes.outlined(palette, textTheme),
    textButtonTheme: AppButtonThemes.text(
      palette,
      textTheme,
      foreground: brightness == Brightness.dark
          ? colorScheme.primaryFixedDim
          : colorScheme.primary,
    ),
    iconButtonTheme: AppButtonThemes.icon(palette),
    floatingActionButtonTheme: AppButtonThemes.floatingAction(colorScheme),
    inputDecorationTheme: AppInputThemes.theme(palette, textTheme, colorScheme),
    segmentedButtonTheme: AppSelectionThemes.segmentedButton(
      palette,
      textTheme,
      colorScheme,
    ),
    chipTheme: AppSelectionThemes.chip(palette, textTheme),

    // --- Progress ---
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: brightness == Brightness.dark
          ? colorScheme.primaryFixedDim
          : colorScheme.primary,
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
