import 'package:flutter/material.dart';

/// Paired colors for selected controls, not reader text highlights.
extension AppSelectionColors on ColorScheme {
  Color get selectedControlBackground => brightness == Brightness.dark
      ? primaryFixedDim
      : primary.withValues(alpha: .08);

  Color get selectedControlForeground =>
      brightness == Brightness.dark ? onPrimaryFixed : primary;
}
