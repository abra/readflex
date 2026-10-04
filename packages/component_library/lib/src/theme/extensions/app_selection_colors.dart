import 'package:flutter/material.dart';

/// Paired colors for selected controls, not reader text highlights.
extension AppSelectionColors on ColorScheme {
  /// Opaque selection markers remain readable over arbitrary cover images.
  Color get selectionMarkerBackground =>
      brightness == Brightness.dark ? primaryFixedDim : primary;

  Color get selectionMarkerForeground =>
      brightness == Brightness.dark ? onPrimaryFixed : onPrimary;

  Color get selectedControlBackground => brightness == Brightness.dark
      ? primaryFixedDim
      : primary.withValues(alpha: .08);

  Color get selectedControlForeground =>
      brightness == Brightness.dark ? onPrimaryFixed : primary;
}
