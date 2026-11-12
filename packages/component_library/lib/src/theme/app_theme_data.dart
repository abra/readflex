import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'app_text_theme.dart';

/// Semantic colours shared by platform presentations.
@immutable
class AppThemeColors {
  const AppThemeColors({
    required this.brightness,
    required this.primary,
    required this.onPrimary,
    required this.primaryFixedDim,
    required this.onPrimaryFixed,
    required this.surface,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.surfaceContainerLowest,
    required this.surfaceContainerLow,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.surfaceContainerHighest,
    required this.secondaryContainer,
    required this.onSecondaryContainer,
    required this.outline,
    required this.outlineVariant,
    required this.inverseSurface,
    required this.onInverseSurface,
    required this.inversePrimary,
    required this.scrim,
    required this.error,
    required this.onError,
    required this.errorContainer,
    required this.onErrorContainer,
  });

  final Brightness brightness;
  final Color primary;
  final Color onPrimary;
  final Color primaryFixedDim;
  final Color onPrimaryFixed;
  final Color surface;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color surfaceContainerLowest;
  final Color surfaceContainerLow;
  final Color surfaceContainer;
  final Color surfaceContainerHigh;
  final Color surfaceContainerHighest;
  final Color secondaryContainer;
  final Color onSecondaryContainer;
  final Color outline;
  final Color outlineVariant;
  final Color inverseSurface;
  final Color onInverseSurface;
  final Color inversePrimary;
  final Color scrim;
  final Color error;
  final Color onError;
  final Color errorContainer;
  final Color onErrorContainer;

  Color get selectionMarkerBackground =>
      brightness == Brightness.dark ? primaryFixedDim : primary;
  Color get selectionMarkerForeground =>
      brightness == Brightness.dark ? onPrimaryFixed : onPrimary;
  Color get selectedControlBackground => brightness == Brightness.dark
      ? primaryFixedDim.withValues(alpha: .16)
      : primary.withValues(alpha: .08);
  Color get selectedControlForeground => selectionMarkerBackground;
}

/// Extra roles belong to Readflex rather than either platform library.
abstract interface class AppStatusColors {
  Color get highlightYellow;
  Color get highlightBlue;
  Color get highlightGreen;
  Color get highlightPink;
  Color get highlightPurple;
  Color get ratingAgain;
  Color get ratingHard;
  Color get ratingGood;
  Color get ratingEasy;
  Color get warning;
  Color get warningForeground;
  Color get info;
  Color get success;
  Color get successForeground;
  Color get successContainer;
  Color get onSuccessContainer;
  Color get successOnInverse;
  Color get errorOnInverse;
  Color get proBadge;
  Color get proBadgeForeground;
  Color get divider;
  Color get onLightSwatch;
  Color get onDarkSwatch;
}

@immutable
class AppThemeData {
  const AppThemeData({
    required this.platform,
    required this.colors,
    required this.text,
    required this.appColors,
    required this.backgroundColor,
    required this.sheetColor,
    required this.selectionHandleColor,
    required this.disabledColor,
  });

  final TargetPlatform platform;
  final AppThemeColors colors;
  final AppTextTheme text;
  final AppStatusColors appColors;
  final Color backgroundColor;
  final Color sheetColor;
  final Color selectionHandleColor;
  final Color disabledColor;

  bool get isCupertino =>
      platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
}
