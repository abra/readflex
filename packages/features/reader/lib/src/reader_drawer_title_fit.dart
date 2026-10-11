import 'package:flutter/painting.dart';

/// A drawer title may shrink to this share of its size before it ellipsizes:
/// enough for "Содержание" at 2x on a 320 px phone, small enough to still
/// read as a title.
const readerDrawerTitleMinFontScale = 0.8;

/// The font size, already scaled for [textScaler], that fits [text] on one
/// line in [maxWidth], or null when the text fits at its own size.
///
/// The result never drops below [minFontScale] of the scaled size; text that
/// is still too long at that size is left to ellipsize. Letter spacing does
/// not scale with the font, so the size is re-measured and corrected a few
/// times rather than derived from one ratio.
double? readerFittedTitleFontSize({
  required String text,
  required TextStyle style,
  required TextScaler textScaler,
  required TextDirection textDirection,
  required double maxWidth,
  double minFontScale = readerDrawerTitleMinFontScale,
}) {
  final scaled = textScaler.scale(style.fontSize ?? 14);
  double widthAt(double fontSize) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: style.copyWith(fontSize: fontSize),
      ),
      textDirection: textDirection,
      maxLines: 1,
    )..layout();
    try {
      return painter.width;
    } finally {
      painter.dispose();
    }
  }

  final natural = widthAt(scaled);
  if (natural <= maxWidth || maxWidth <= 0) return null;
  final minimum = scaled * minFontScale;
  var size = scaled * maxWidth / natural;
  for (var attempt = 0; attempt < 3 && size > minimum; attempt++) {
    final width = widthAt(size);
    if (width <= maxWidth) break;
    // A hair under the ratio, so rounding cannot leave a sub-pixel overflow.
    size *= maxWidth / width * 0.999;
  }
  return size < minimum ? minimum : size;
}
