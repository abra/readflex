import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_spacing.dart';

/// SegmentedButton, Chip, and related selection component themes.
class AppSelectionThemes {
  AppSelectionThemes._();

  static SegmentedButtonThemeData segmentedButton(
    AppColorPalette palette,
    TextTheme textTheme,
  ) {
    return SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return palette.surfaceElevated;
          }
          return palette.muted;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return palette.foreground;
          }
          return palette.mutedForeground;
        }),
        textStyle: WidgetStatePropertyAll(textTheme.labelMedium),
        side: WidgetStatePropertyAll(BorderSide(color: palette.border)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
    );
  }

  static ChipThemeData chip(
    AppColorPalette palette,
    TextTheme textTheme,
  ) {
    return ChipThemeData(
      backgroundColor: palette.muted,
      selectedColor: palette.surfaceElevated,
      disabledColor: palette.muted,
      side: BorderSide(color: palette.border),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      labelStyle: textTheme.labelMedium!.copyWith(color: palette.foreground),
      secondaryLabelStyle: textTheme.labelMedium!.copyWith(
        color: palette.foreground,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
    );
  }
}
