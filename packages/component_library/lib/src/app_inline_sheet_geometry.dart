import 'dart:math' as math;

import 'theme/tokens/app_spacing.dart';

/// Rest positions of an inline sheet, as values of its position animation:
/// the sheet slides in from closed to half, then grows from half to full.
abstract final class AppInlineSheetPosition {
  static const double closed = 0;
  static const double half = 1;
  static const double full = 2;
}

/// Heights of an inline sheet for the space it is laid out in.
///
/// Full stops [topGap] below the status bar, above the keyboard, so the
/// dimmed page stays visible over the sheet. Half is 60% of that, scaled with
/// the text so large text keeps about the same number of rows in view, and
/// never below [minHalfHeight]. When half would leave less than a quarter of
/// the full height to grow into (a landscape phone, large text, a keyboard
/// on a small screen) the sheet has one position and opens at full.
///
/// When even full is shorter than [minHalfHeight], the content is laid out at
/// that height and scrolls as a whole ([scrollsContent]). 320dp holds a
/// header, tabs, a search field and a row at 200% text.
class AppInlineSheetGeometry {
  const AppInlineSheetGeometry({required this.half, required this.full})
    : assert(half <= full);

  factory AppInlineSheetGeometry.resolve({
    required double maxHeight,
    required double keyboardInset,
    required double topInset,
    double textScale = 1,
  }) {
    final scale = math.max(1.0, textScale);
    final full = math.max(0.0, maxHeight - keyboardInset - topInset - topGap);
    final preferredHalf = math.max(full * halfFraction * scale, minHalfHeight);
    final half = math.min(full, preferredHalf);
    return AppInlineSheetGeometry(
      half: half > full * maxHalfShare ? full : half,
      full: full,
    );
  }

  static const double halfFraction = 0.6;
  static const double minHalfHeight = 320;
  static const double topGap = AppSpacing.sm;

  /// Above this share of full, half and full merge into one position.
  static const double maxHalfShare = 0.75;

  final double half;
  final double full;

  bool get canExpand => full > half;

  /// Whether even full is too short for the content, which then scrolls as a
  /// whole at [minHalfHeight].
  bool get scrollsContent => full < minHalfHeight;

  /// Laid-out height at [position]. Below half the sheet keeps its half
  /// height and only slides, so content is never squeezed while it opens.
  double heightAt(double position) {
    if (position <= AppInlineSheetPosition.half) return half;
    return half + (full - half) * (position - AppInlineSheetPosition.half);
  }

  /// How far the sheet's top edge sits above its bottom edge at [position].
  double extentAt(double position) {
    if (position <= AppInlineSheetPosition.half) return half * position;
    return heightAt(position);
  }

  /// Downward slide that hides the part of a half-height sheet below
  /// [extentAt].
  double slideAt(double position) => heightAt(position) - extentAt(position);

  /// The position whose [extentAt] is [extent], for direct manipulation.
  double positionForExtent(double extent) {
    if (half <= 0) return AppInlineSheetPosition.closed;
    if (extent <= half) return extent / half;
    if (!canExpand) return AppInlineSheetPosition.half;
    final grown = (extent - half) / (full - half);
    return AppInlineSheetPosition.half + math.min(grown, 1);
  }

  @override
  bool operator ==(Object other) =>
      other is AppInlineSheetGeometry &&
      other.half == half &&
      other.full == full;

  @override
  int get hashCode => Object.hash(half, full);

  @override
  String toString() => 'AppInlineSheetGeometry(half: $half, full: $full)';
}
