import 'package:flutter/material.dart';

/// Dimension tokens delivered via [ThemeExtension].
///
/// Access in UI: `Theme.of(context).extension<AppDimensExt>()!`
/// or the shorthand `context.dimens`.
@immutable
class AppDimensExt extends ThemeExtension<AppDimensExt> {
  const AppDimensExt({
    // Spacing
    required this.spacingXxs,
    required this.spacingXs,
    required this.spacingSm,
    required this.spacingMd,
    required this.spacingLg,
    required this.spacingXl,
    required this.spacingXxl,
    required this.spacingXxxl,
    required this.spacingXxxxl,
    // Radius
    required this.radiusXs,
    required this.radiusSm,
    required this.radiusMd,
    required this.radiusLg,
    required this.radiusXl,
    required this.radiusXxl,
    // Sizes
    required this.buttonHeight,
    required this.inputHeight,
    required this.iconButtonSize,
  });

  // ── Spacing ──────────────────────────────────────────────
  final double spacingXxs;
  final double spacingXs;
  final double spacingSm;
  final double spacingMd;
  final double spacingLg;
  final double spacingXl;
  final double spacingXxl;
  final double spacingXxxl;
  final double spacingXxxxl;

  // ── Radius ───────────────────────────────────────────────
  final double radiusXs;
  final double radiusSm;
  final double radiusMd;
  final double radiusLg;
  final double radiusXl;
  final double radiusXxl;

  // ── Control sizes ────────────────────────────────────────
  final double buttonHeight;
  final double inputHeight;
  final double iconButtonSize;

  @override
  AppDimensExt copyWith({
    double? spacingXxs,
    double? spacingXs,
    double? spacingSm,
    double? spacingMd,
    double? spacingLg,
    double? spacingXl,
    double? spacingXxl,
    double? spacingXxxl,
    double? spacingXxxxl,
    double? radiusXs,
    double? radiusSm,
    double? radiusMd,
    double? radiusLg,
    double? radiusXl,
    double? radiusXxl,
    double? buttonHeight,
    double? inputHeight,
    double? iconButtonSize,
  }) {
    return AppDimensExt(
      spacingXxs: spacingXxs ?? this.spacingXxs,
      spacingXs: spacingXs ?? this.spacingXs,
      spacingSm: spacingSm ?? this.spacingSm,
      spacingMd: spacingMd ?? this.spacingMd,
      spacingLg: spacingLg ?? this.spacingLg,
      spacingXl: spacingXl ?? this.spacingXl,
      spacingXxl: spacingXxl ?? this.spacingXxl,
      spacingXxxl: spacingXxxl ?? this.spacingXxxl,
      spacingXxxxl: spacingXxxxl ?? this.spacingXxxxl,
      radiusXs: radiusXs ?? this.radiusXs,
      radiusSm: radiusSm ?? this.radiusSm,
      radiusMd: radiusMd ?? this.radiusMd,
      radiusLg: radiusLg ?? this.radiusLg,
      radiusXl: radiusXl ?? this.radiusXl,
      radiusXxl: radiusXxl ?? this.radiusXxl,
      buttonHeight: buttonHeight ?? this.buttonHeight,
      inputHeight: inputHeight ?? this.inputHeight,
      iconButtonSize: iconButtonSize ?? this.iconButtonSize,
    );
  }

  @override
  AppDimensExt lerp(covariant ThemeExtension<AppDimensExt>? other, double t) {
    if (other is! AppDimensExt) return this;

    double _lerp(double a, double b) => a + (b - a) * t;

    return AppDimensExt(
      spacingXxs: _lerp(spacingXxs, other.spacingXxs),
      spacingXs: _lerp(spacingXs, other.spacingXs),
      spacingSm: _lerp(spacingSm, other.spacingSm),
      spacingMd: _lerp(spacingMd, other.spacingMd),
      spacingLg: _lerp(spacingLg, other.spacingLg),
      spacingXl: _lerp(spacingXl, other.spacingXl),
      spacingXxl: _lerp(spacingXxl, other.spacingXxl),
      spacingXxxl: _lerp(spacingXxxl, other.spacingXxxl),
      spacingXxxxl: _lerp(spacingXxxxl, other.spacingXxxxl),
      radiusXs: _lerp(radiusXs, other.radiusXs),
      radiusSm: _lerp(radiusSm, other.radiusSm),
      radiusMd: _lerp(radiusMd, other.radiusMd),
      radiusLg: _lerp(radiusLg, other.radiusLg),
      radiusXl: _lerp(radiusXl, other.radiusXl),
      radiusXxl: _lerp(radiusXxl, other.radiusXxl),
      buttonHeight: _lerp(buttonHeight, other.buttonHeight),
      inputHeight: _lerp(inputHeight, other.inputHeight),
      iconButtonSize: _lerp(iconButtonSize, other.iconButtonSize),
    );
  }
}
