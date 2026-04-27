import 'package:flutter/material.dart';

import 'primitive_colors.dart';

/// Semantic color palette — maps [PrimitiveColors] to UI roles.
///
/// Used only inside theme assembly to build [ColorScheme].
/// Widgets read colors from `Theme.of(context).colorScheme`
/// or `Theme.of(context).extension<AppColorsExt>()`.
class AppColorPalette {
  const AppColorPalette({
    required this.background,
    required this.foreground,
    required this.primary,
    required this.onPrimary,
    required this.secondary,
    required this.onSecondary,
    required this.muted,
    required this.mutedForeground,
    required this.card,
    required this.border,
    required this.error,
    required this.onError,
    required this.surfaceElevated,
  });

  final Color background;
  final Color foreground;
  final Color primary;
  final Color onPrimary;
  final Color secondary;
  final Color onSecondary;
  final Color muted;
  final Color mutedForeground;
  final Color card;
  final Color border;
  final Color error;
  final Color onError;
  final Color surfaceElevated;
}

const lightPalette = AppColorPalette(
  background: PrimitiveColors.gray50,
  foreground: PrimitiveColors.gray900,
  primary: PrimitiveColors.orange500,
  onPrimary: PrimitiveColors.white,
  secondary: PrimitiveColors.gray200,
  onSecondary: PrimitiveColors.gray700,
  muted: PrimitiveColors.gray300,
  mutedForeground: PrimitiveColors.gray600,
  card: PrimitiveColors.gray100,
  border: PrimitiveColors.gray350,
  error: PrimitiveColors.red500,
  onError: PrimitiveColors.white,
  surfaceElevated: PrimitiveColors.white,
);

const darkPalette = AppColorPalette(
  background: PrimitiveColors.darkGray900,
  foreground: PrimitiveColors.darkGray50,
  primary: PrimitiveColors.orange400,
  onPrimary: PrimitiveColors.white,
  secondary: PrimitiveColors.darkGray700,
  onSecondary: PrimitiveColors.darkGray200,
  muted: PrimitiveColors.darkGray600,
  mutedForeground: PrimitiveColors.darkGray400,
  card: PrimitiveColors.darkGray750,
  border: PrimitiveColors.darkGray600,
  error: PrimitiveColors.red600,
  onError: PrimitiveColors.white,
  surfaceElevated: PrimitiveColors.darkGray800,
);
