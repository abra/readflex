part of 'app_choice_control.dart';

@immutable
class _AppChoiceMeasurementKey {
  const _AppChoiceMeasurementKey({
    required this.labels,
    required this.textDirection,
    required this.textScaler,
    required this.locale,
    required this.cupertino,
    required this.proportionalWidth,
    required this.iconOnly,
  });

  final List<({String label, TextStyle style, bool hasIcon})> labels;
  final TextDirection textDirection;
  final TextScaler textScaler;
  final Locale? locale;
  final bool cupertino;
  final bool proportionalWidth;
  final bool iconOnly;

  bool _sameLabels(_AppChoiceMeasurementKey other) {
    if (labels.length != other.labels.length) return false;
    for (var index = 0; index < labels.length; index++) {
      final label = labels[index];
      final previous = other.labels[index];
      if (label.label != previous.label ||
          label.hasIcon != previous.hasIcon ||
          label.style.compareTo(previous.style) == RenderComparison.layout) {
        return false;
      }
    }
    return true;
  }

  @override
  bool operator ==(Object other) =>
      other is _AppChoiceMeasurementKey &&
      _sameLabels(other) &&
      textDirection == other.textDirection &&
      textScaler == other.textScaler &&
      locale == other.locale &&
      cupertino == other.cupertino &&
      proportionalWidth == other.proportionalWidth &&
      iconOnly == other.iconOnly;

  @override
  int get hashCode => Object.hash(
    // Paint-only text changes do not invalidate cached geometry.
    Object.hashAll(labels.map((label) => (label.label, label.hasIcon))),
    textDirection,
    textScaler,
    locale,
    cupertino,
    proportionalWidth,
    iconOnly,
  );
}

/// Label shaping is cached separately from the available width and selection.
/// Reserve Cupertino's heavier selected face to avoid reflow on each tap.
class _AppChoiceMeasurements {
  const _AppChoiceMeasurements({
    required this.key,
    required this.widest,
    required this.totalWidth,
  });

  factory _AppChoiceMeasurements.measure(_AppChoiceMeasurementKey key) {
    var widest = AppSizes.buttonHeight;
    var totalWidth = AppSizes.buttonHeight * key.labels.length;
    if (!key.iconOnly) {
      totalWidth = 0;
      final painter = TextPainter(
        textDirection: key.textDirection,
        textScaler: key.textScaler,
        locale: key.locale,
      );
      for (final label in key.labels) {
        final style =
            key.cupertino &&
                (label.style.fontWeight ?? FontWeight.w400).value <
                    FontWeight.w600.value
            ? label.style.copyWith(fontWeight: FontWeight.w600)
            : label.style;
        painter.text = TextSpan(text: label.label, style: style);
        painter.layout();
        final contentWidth =
            painter.width +
            (label.hasIcon ? AppIconSize.sm + AppSpacing.sm : 0);
        final width = key.proportionalWidth
            ? math.max(AppSizes.buttonHeight, contentWidth) + AppSpacing.md * 2
            : math.max(
                AppSizes.buttonHeight,
                contentWidth + AppSpacing.md * 2,
              );
        widest = math.max(widest, width);
        totalWidth += width;
      }
      painter.dispose();
    }
    return _AppChoiceMeasurements(
      key: key,
      widest: widest,
      totalWidth: totalWidth,
    );
  }

  final _AppChoiceMeasurementKey key;
  final double widest;
  final double totalWidth;
}
