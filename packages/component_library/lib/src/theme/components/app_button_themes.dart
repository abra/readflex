import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_sizes.dart';
import '../tokens/app_spacing.dart';

/// Button component themes built from tokens.
class AppButtonThemes {
  AppButtonThemes._();

  static final _controlShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadius.md),
  );

  static FilledButtonThemeData filled(
    AppColorPalette palette,
    TextTheme textTheme,
  ) {
    return FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: palette.primary,
        foregroundColor: palette.onPrimary,
        textStyle: textTheme.labelLarge,
        elevation: 0,
        shadowColor: Colors.transparent,
        // `Size(0, h)`, NOT `Size.fromHeight(h)`. The latter is
        // `Size(double.infinity, h)`, which makes minimumSize.width
        // infinite — fine when the parent gives a bounded width
        // (full-width buttons in sheets), but inside a Row without an
        // Expanded wrapper around the button it forces the layout
        // into "infinite width" and the frame fails.
        minimumSize: const Size(0, AppSizes.buttonHeight),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        shape: _controlShape,
      ),
    );
  }

  static OutlinedButtonThemeData outlined(
    AppColorPalette palette,
    TextTheme textTheme,
  ) {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.foreground,
        textStyle: textTheme.labelLarge,
        // `Size(0, h)`, NOT `Size.fromHeight(h)`. The latter is
        // `Size(double.infinity, h)`, which makes minimumSize.width
        // infinite — fine when the parent gives a bounded width
        // (full-width buttons in sheets), but inside a Row without an
        // Expanded wrapper around the button it forces the layout
        // into "infinite width" and the frame fails.
        minimumSize: const Size(0, AppSizes.buttonHeight),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        side: BorderSide(color: palette.border),
        backgroundColor: palette.secondary,
        shape: _controlShape,
      ),
    );
  }

  static TextButtonThemeData text(
    AppColorPalette palette,
    TextTheme textTheme,
  ) {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: palette.primary,
        textStyle: textTheme.labelLarge,
        // `Size(0, h)`, NOT `Size.fromHeight(h)`. The latter is
        // `Size(double.infinity, h)`, which makes minimumSize.width
        // infinite — fine when the parent gives a bounded width
        // (full-width buttons in sheets), but inside a Row without an
        // Expanded wrapper around the button it forces the layout
        // into "infinite width" and the frame fails.
        minimumSize: const Size(0, AppSizes.buttonHeight),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        shape: _controlShape,
      ),
    );
  }

  static IconButtonThemeData icon(AppColorPalette palette) {
    return IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: palette.foreground,
        backgroundColor: palette.secondary,
        minimumSize: const Size.square(AppSizes.iconButtonSize),
        padding: const EdgeInsets.all(AppSpacing.sm),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
    );
  }
}
