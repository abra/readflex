import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_elevation.dart';
import '../tokens/app_radius.dart';

/// Card component theme built from tokens.
class AppCardThemes {
  AppCardThemes._();

  static CardThemeData theme(AppColorPalette palette) {
    return CardThemeData(
      color: palette.card,
      elevation: AppElevation.level0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        side: BorderSide(color: palette.border),
      ),
    );
  }
}
