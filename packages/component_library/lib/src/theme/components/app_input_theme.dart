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
  ) {
    final inputRadius = BorderRadius.circular(AppRadius.lg);

    return InputDecorationTheme(
      filled: true,
      fillColor: palette.secondary,
      hintStyle: textTheme.bodyMedium!.copyWith(
        color: palette.foreground.withValues(alpha: 0.4),
      ),
      labelStyle: textTheme.bodyMedium!.copyWith(
        color: palette.mutedForeground,
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
