import 'package:flutter/material.dart';

import '../app_typography.dart';
import '../extensions/app_selection_colors.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_sizes.dart';

/// SegmentedButton, Chip, and related selection component themes.
class AppSelectionThemes {
  AppSelectionThemes._();

  static SegmentedButtonThemeData segmentedButton(
    AppColorPalette palette,
    TextTheme textTheme,
    ColorScheme colors,
  ) {
    return SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            if (states.contains(WidgetState.disabled) &&
                colors.brightness == Brightness.dark) {
              return colors.onSurface.withValues(alpha: .12);
            }
            return colors.selectedControlBackground;
          }
          return colors.surface;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return colors.onSurface.withValues(alpha: .38);
          }
          if (states.contains(WidgetState.selected)) {
            return colors.selectedControlForeground;
          }
          return colors.onSurfaceVariant;
        }),
        textStyle: WidgetStatePropertyAll(
          textTheme.bodyMedium!.copyWith(
            letterSpacing: 0,
            fontFamily: AppTypography.fontFamilySans,
            fontFamilyFallback: AppTypography.fontFamilyFallback,
          ),
        ),
        visualDensity: VisualDensity.standard,
        tapTargetSize: MaterialTapTargetSize.padded,
        minimumSize: const WidgetStatePropertyAll(
          Size(AppSizes.buttonHeight, AppSizes.buttonHeight),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
        ),
        side: WidgetStatePropertyAll(BorderSide(color: palette.border)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
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
