import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_spacing.dart';

/// Input field component theme built from tokens.
class AppInputThemes {
  AppInputThemes._();

  static InputDecorationTheme theme(
    AppColorPalette palette,
    TextTheme textTheme,
    ColorScheme colors,
  ) {
    // The search field's and buttons' radius, so every field reads as one
    // control family.
    final inputRadius = BorderRadius.circular(AppRadius.md);

    return InputDecorationTheme(
      filled: true,
      fillColor: palette.secondary,
      hintStyle: textTheme.bodyMedium!.copyWith(
        color: colors.onSurfaceVariant,
      ),
      labelStyle: textTheme.bodyMedium!.copyWith(
        color: colors.onSurfaceVariant,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      border: OutlineInputBorder(
        borderRadius: inputRadius,
        borderSide: BorderSide(
          color: palette.border.withValues(alpha: 0.6),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: inputRadius,
        borderSide: BorderSide(
          color: palette.border.withValues(alpha: 0.6),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: inputRadius,
        borderSide: BorderSide(
          color: palette.foreground.withValues(alpha: 0.4),
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: inputRadius,
        borderSide: BorderSide(color: palette.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: inputRadius,
        borderSide: BorderSide(color: palette.error, width: 1.2),
      ),
    );
  }
}
