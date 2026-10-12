import 'package:flutter/painting.dart';

/// Width a `SelectableText` keeps after its text for the caret: Flutter's
/// 1dp caret gap plus the default 2dp cursor. Text measured for a
/// `SelectableText` box uses the box width minus this margin, or a word that
/// fits the measurement still wraps on screen.
const double appSelectableTextCaretMargin = 3;

/// Returns [style] at the largest font size at which the longest word of
/// [text] fits [maxWidth], so a large heading never breaks inside a word.
///
/// Text that only wraps between words keeps its size. The size stays
/// between [minFontSize] and the style's own size; a word wider than
/// [maxWidth] even at [minFontSize] breaks, as the last resort. The result is
/// the unscaled size: a `Text` rendering it with [textScaler] matches the
/// measurement, including nonlinear scaling.
TextStyle appFitLongestWord(
  TextStyle style, {
  required String text,
  required double maxWidth,
  required double minFontSize,
  required TextScaler textScaler,
  required TextDirection textDirection,
  Locale? locale,
}) {
  final fontSize = style.fontSize;
  assert(fontSize != null, 'appFitLongestWord needs a style with a size.');
  if (fontSize == null || fontSize <= minFontSize) return style;
  final painter = TextPainter(
    textDirection: textDirection,
    textScaler: textScaler,
    locale: locale,
  );
  try {
    bool fits(double size) {
      painter
        ..text = TextSpan(
          text: text,
          style: style.copyWith(fontSize: size),
        )
        ..layout();
      // The widest unbreakable run, whatever the wrap width.
      return painter.minIntrinsicWidth <= maxWidth;
    }

    if (fits(fontSize)) return style;
    if (!fits(minFontSize)) return style.copyWith(fontSize: minFontSize);
    var fitting = minFontSize;
    var tooLarge = fontSize;
    while (tooLarge - fitting > _sizePrecision) {
      final size = (fitting + tooLarge) / 2;
      if (fits(size)) {
        fitting = size;
      } else {
        tooLarge = size;
      }
    }
    return style.copyWith(fontSize: fitting);
  } finally {
    painter.dispose();
  }
}

// Finer steps than this are not visible in a heading.
const _sizePrecision = 0.25;
