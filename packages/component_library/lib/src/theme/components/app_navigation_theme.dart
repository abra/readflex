import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_elevation.dart';
import '../tokens/app_sizes.dart';
import '../tokens/app_spacing.dart';

/// NavigationBar and BottomSheet component themes built from tokens.
class AppNavigationThemes {
  AppNavigationThemes._();

  static NavigationBarThemeData navigationBar(
    AppColorPalette palette,
    TextTheme textTheme,
  ) {
    return NavigationBarThemeData(
      backgroundColor: palette.background,
      surfaceTintColor: Colors.transparent,
      elevation: AppElevation.level0,
      indicatorColor: Colors.transparent,
      height: AppSizes.navBarHeight,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelPadding: const EdgeInsets.only(top: AppSpacing.xs),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final isSelected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: isSelected ? palette.foreground : palette.mutedForeground,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final isSelected = states.contains(WidgetState.selected);
        return textTheme.labelSmall!.copyWith(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          color: isSelected ? palette.foreground : palette.mutedForeground,
        );
      }),
    );
  }

  static BottomSheetThemeData bottomSheet(AppColorPalette palette) {
    return BottomSheetThemeData(
      backgroundColor: palette.background,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: palette.background,
      showDragHandle: false,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSizes.bottomSheetRadius),
        ),
      ),
    );
  }

  static DialogThemeData dialog(AppColorPalette palette) {
    return DialogThemeData(
      backgroundColor: palette.background,
      surfaceTintColor: Colors.transparent,
      elevation: AppElevation.level0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.bottomSheetRadius),
      ),
    );
  }
}
