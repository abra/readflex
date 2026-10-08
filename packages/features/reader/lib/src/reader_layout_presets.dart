import 'package:preferences_service/preferences_service.dart';

/// Line spacing choices of the Appearance sheet.
///
/// Normal is the reader default (1.6); Compact (1.4) and Relaxed (1.8) are the
/// stored presets one step either side of it, so they survive
/// [ReaderAppearancePreferences.normalizeLineHeight] unchanged.
enum ReaderLineSpacingPreset {
  compact(1.4),
  normal(ReaderAppearancePreferences.defaultLineHeight),
  relaxed(1.8);

  const ReaderLineSpacingPreset(this.lineHeight);

  final double lineHeight;

  /// The preset closest to [lineHeight]; a midpoint resolves to [normal].
  static ReaderLineSpacingPreset nearest(double lineHeight) => _nearest(
    values,
    normal,
    lineHeight,
    (preset) => preset.lineHeight,
  );
}

/// Page margin choices, in percent of the page width like `sideMargin`.
///
/// Medium is the reader default (8); Narrow (4) and Wide (12) sit 4 points
/// either side of it, inside the 2–14 range the reader accepts.
enum ReaderMarginPreset {
  narrow(4),
  medium(8),
  wide(12);

  const ReaderMarginPreset(this.sideMargin);

  final double sideMargin;

  /// The preset closest to [sideMargin]; a midpoint resolves to [medium].
  static ReaderMarginPreset nearest(double sideMargin) => _nearest(
    values,
    medium,
    sideMargin,
    (preset) => preset.sideMargin,
  );
}

// Absorbs float noise such as |1.5 - 1.4| < |1.5 - 1.6|, so a midpoint is a
// tie and keeps the default preset.
const double _tieTolerance = 1e-9;

T _nearest<T>(
  List<T> presets,
  T fallback,
  double value,
  double Function(T preset) valueOf,
) {
  var nearest = fallback;
  var nearestDistance = (value - valueOf(fallback)).abs();
  for (final preset in presets) {
    final distance = (value - valueOf(preset)).abs();
    if (distance < nearestDistance - _tieTolerance) {
      nearest = preset;
      nearestDistance = distance;
    }
  }
  return nearest;
}
