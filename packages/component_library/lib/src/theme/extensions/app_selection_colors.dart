import 'package:flutter/material.dart';

/// Tint of the accent behind a selected control. Light mode tints the wine
/// primary; dark mode tints its light pink tone, which needs a stronger wash
/// to read on the near-black surfaces.
const double _lightSelectedControlAlpha = .08;
const double _darkSelectedControlAlpha = .16;

/// Paired colors for selected controls, not reader text highlights.
extension AppSelectionColors on ColorScheme {
  /// Opaque selection markers remain readable over arbitrary cover images.
  Color get selectionMarkerBackground =>
      brightness == Brightness.dark ? primaryFixedDim : primary;

  Color get selectionMarkerForeground =>
      brightness == Brightness.dark ? onPrimaryFixed : onPrimary;

  /// A translucent accent wash in both themes, so a selected segment, row or
  /// card reads as tinted rather than as the brightest block on the screen.
  Color get selectedControlBackground => brightness == Brightness.dark
      ? primaryFixedDim.withValues(alpha: _darkSelectedControlAlpha)
      : primary.withValues(alpha: _lightSelectedControlAlpha);

  /// The accent itself, readable on [selectedControlBackground] over every
  /// app surface.
  Color get selectedControlForeground =>
      brightness == Brightness.dark ? primaryFixedDim : primary;
}
