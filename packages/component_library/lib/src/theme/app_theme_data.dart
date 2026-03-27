import 'package:flutter/material.dart';

/// Font family constants used across the theme.
const kFontFamilySans = 'Inter';
const kFontFamilySerif = 'SourceSerif4';

// Display & headline styles use Source Serif 4 for a warm literary feel.
// Body, title, and label styles use Inter for clean UI readability.
const _textTheme = TextTheme(
  displayLarge: TextStyle(
    fontFamily: kFontFamilySerif,
    fontSize: 52,
    height: 1.04,
    fontWeight: FontWeight.w600,
  ),
  displayMedium: TextStyle(
    fontFamily: kFontFamilySerif,
    fontSize: 44,
    height: 1.06,
    fontWeight: FontWeight.w600,
  ),
  displaySmall: TextStyle(
    fontFamily: kFontFamilySerif,
    fontSize: 36,
    height: 1.08,
    fontWeight: FontWeight.w600,
  ),
  headlineLarge: TextStyle(
    fontFamily: kFontFamilySerif,
    fontSize: 32,
    height: 1.12,
    fontWeight: FontWeight.w600,
  ),
  headlineMedium: TextStyle(
    fontFamily: kFontFamilySerif,
    fontSize: 28,
    height: 1.16,
    fontWeight: FontWeight.w600,
  ),
  headlineSmall: TextStyle(
    fontFamily: kFontFamilySerif,
    fontSize: 24,
    height: 1.2,
    fontWeight: FontWeight.w600,
  ),
  titleLarge: TextStyle(
    fontSize: 20,
    height: 1.24,
    fontWeight: FontWeight.w600,
  ),
  titleMedium: TextStyle(
    fontSize: 17,
    height: 1.28,
    fontWeight: FontWeight.w600,
  ),
  titleSmall: TextStyle(fontSize: 15, height: 1.3, fontWeight: FontWeight.w600),
  bodyLarge: TextStyle(fontSize: 17, height: 1.45, fontWeight: FontWeight.w400),
  bodyMedium: TextStyle(
    fontSize: 15,
    height: 1.45,
    fontWeight: FontWeight.w400,
  ),
  bodySmall: TextStyle(fontSize: 13, height: 1.4, fontWeight: FontWeight.w400),
  labelLarge: TextStyle(fontSize: 15, height: 1.2, fontWeight: FontWeight.w600),
  labelMedium: TextStyle(
    fontSize: 13,
    height: 1.2,
    fontWeight: FontWeight.w600,
  ),
  labelSmall: TextStyle(fontSize: 12, height: 1.2, fontWeight: FontWeight.w600),
);

final class _ThemePalette {
  const _ThemePalette({
    required this.scaffold,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceTint,
    required this.primary,
    required this.onPrimary,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.borderStrong,
    required this.error,
    required this.onError,
  });

  final Color scaffold;
  final Color surface;
  final Color surfaceRaised;
  final Color surfaceTint;
  final Color primary;
  final Color onPrimary;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color borderStrong;
  final Color error;
  final Color onError;
}

const _lightPalette = _ThemePalette(
  scaffold: Color(0xFFF8F4EC),
  surface: Color(0xFFFFFCF7),
  surfaceRaised: Color(0xFFF5EFE4),
  surfaceTint: Color(0xFFF0E7D8),
  primary: Color(0xFFB86A2D),
  onPrimary: Colors.white,
  textPrimary: Color(0xFF241C16),
  textSecondary: Color(0xFF7A6E62),
  border: Color(0xFFE6DAC8),
  borderStrong: Color(0xFFD7C6AE),
  error: Color(0xFFB45145),
  onError: Colors.white,
);

const _darkPalette = _ThemePalette(
  scaffold: Color(0xFF1E1B18),
  surface: Color(0xFF24201D),
  surfaceRaised: Color(0xFF2A2521),
  surfaceTint: Color(0xFF332D28),
  primary: Color(0xFFD08A4A),
  onPrimary: Color(0xFF22170D),
  textPrimary: Color(0xFFF2E7D8),
  textSecondary: Color(0xFFB6A898),
  border: Color(0xFF3C342D),
  borderStrong: Color(0xFF4A4038),
  error: Color(0xFFE08174),
  onError: Color(0xFF2A120E),
);

/// Abstract base class describing the app's theme.
abstract class AppThemeData {
  const AppThemeData();

  /// The Material [ThemeData] passed to [MaterialApp.theme] or [MaterialApp.darkTheme].
  ThemeData get materialThemeData;
}

/// Light variant of [AppThemeData] with warm paper-like surfaces.
final class LightAppThemeData extends AppThemeData {
  const LightAppThemeData();

  static final _cached = _buildTheme(
    palette: _lightPalette,
    brightness: Brightness.light,
  );

  @override
  ThemeData get materialThemeData => _cached;
}

/// Dark variant of [AppThemeData] using a calm charcoal reading palette.
final class DarkAppThemeData extends AppThemeData {
  const DarkAppThemeData();

  static final _cached = _buildTheme(
    palette: _darkPalette,
    brightness: Brightness.dark,
  );

  @override
  ThemeData get materialThemeData => _cached;
}

ThemeData _buildTheme({
  required _ThemePalette palette,
  required Brightness brightness,
}) {
  final colorScheme = ColorScheme(
    brightness: brightness,
    primary: palette.primary,
    onPrimary: palette.onPrimary,
    secondary: palette.primary,
    onSecondary: palette.onPrimary,
    error: palette.error,
    onError: palette.onError,
    surface: palette.surface,
    onSurface: palette.textPrimary,
    surfaceContainerHighest: palette.surfaceTint,
    surfaceContainerHigh: palette.surfaceRaised,
    surfaceContainer: palette.surface,
    surfaceContainerLow: palette.scaffold,
    primaryContainer: palette.surfaceTint,
    onPrimaryContainer: palette.textPrimary,
    onSurfaceVariant: palette.textSecondary,
    outline: palette.border,
    outlineVariant: palette.borderStrong,
  );

  final textTheme = _textTheme.apply(
    fontFamily: kFontFamilySans,
    bodyColor: palette.textPrimary,
    displayColor: palette.textPrimary,
  );

  final cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(22),
    side: BorderSide(color: palette.border),
  );
  final controlShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: kFontFamilySans,
    textTheme: textTheme,
    scaffoldBackgroundColor: palette.scaffold,
    colorScheme: colorScheme,
    dividerTheme: DividerThemeData(
      color: palette.border,
      thickness: 0.5,
      space: 1,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      },
    ),
    splashFactory: NoSplash.splashFactory,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: palette.scaffold,
      foregroundColor: palette.textPrimary,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      toolbarHeight: 52,
      titleTextStyle: textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardThemeData(
      color: palette.surfaceRaised,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: cardShape,
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      iconColor: palette.textSecondary,
      textColor: palette.textPrimary,
      tileColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: palette.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: brightness == Brightness.light
          ? palette.primary.withValues(alpha: 0.12)
          : palette.primary.withValues(alpha: 0.18),
      height: 70,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelPadding: const EdgeInsets.only(top: 4),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final isSelected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: isSelected ? palette.textPrimary : palette.textSecondary,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final isSelected = states.contains(WidgetState.selected);
        return textTheme.labelSmall!.copyWith(
          color: isSelected ? palette.textPrimary : palette.textSecondary,
        );
      }),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: palette.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: palette.surfaceRaised,
      showDragHandle: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: palette.primary,
        foregroundColor: palette.onPrimary,
        textStyle: textTheme.labelLarge,
        elevation: 0,
        shadowColor: Colors.transparent,
        minimumSize: const Size.fromHeight(50),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        shape: controlShape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.textPrimary,
        textStyle: textTheme.labelLarge,
        minimumSize: const Size.fromHeight(50),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        side: BorderSide(color: palette.border),
        backgroundColor: palette.surfaceRaised,
        shape: controlShape,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: palette.primary,
        textStyle: textTheme.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: controlShape,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: palette.textPrimary,
        backgroundColor: palette.surfaceRaised,
        minimumSize: const Size.square(40),
        padding: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: brightness == Brightness.light
          ? palette.surfaceTint
          : palette.surfaceTint.withValues(alpha: 0.72),
      hintStyle: textTheme.bodyMedium?.copyWith(color: palette.textSecondary),
      labelStyle: textTheme.bodyMedium?.copyWith(color: palette.textSecondary),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: palette.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: palette.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: palette.primary, width: 1.2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: palette.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: palette.error, width: 1.2),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return brightness == Brightness.light
                ? palette.surface
                : palette.surfaceRaised;
          }
          return palette.surfaceTint;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return palette.textPrimary;
          }
          return palette.textSecondary;
        }),
        textStyle: WidgetStatePropertyAll(textTheme.labelMedium),
        side: WidgetStatePropertyAll(BorderSide(color: palette.border)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: brightness == Brightness.light
          ? palette.surfaceTint
          : palette.surfaceTint.withValues(alpha: 0.8),
      selectedColor: brightness == Brightness.light
          ? palette.surface
          : palette.surfaceRaised,
      disabledColor: palette.surfaceTint,
      side: BorderSide(color: palette.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      labelStyle: textTheme.labelMedium!.copyWith(color: palette.textPrimary),
      secondaryLabelStyle: textTheme.labelMedium!.copyWith(
        color: palette.textPrimary,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: palette.primary,
      linearTrackColor: palette.surfaceTint,
      circularTrackColor: palette.surfaceTint,
    ),
    sliderTheme: SliderThemeData(
      trackHeight: 3,
      activeTrackColor: palette.primary,
      inactiveTrackColor: palette.surfaceTint,
      thumbColor: palette.primary,
      overlayColor: palette.primary.withValues(alpha: 0.12),
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
    ),
  );
}
