import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'library_title_layout.dart';

/// The title never takes more lines than this, so the Continue reading card
/// stays bounded however long the title is.
const int kContinueReadingTitleMaxLines = 3;

/// Smallest title font relative to the theme role: about the author line's
/// size, so the title never reads smaller than its metadata.
const double kContinueReadingTitleMinFontScale = 0.8;

const double _fontScaleStep = 0.05;

/// How the Continue reading card fits its title.
class ContinueReadingTitleLayout {
  const ContinueReadingTitleLayout({
    required this.fontScale,
    required this.truncated,
  });

  /// Multiplier for the title role's font size.
  final double fontScale;

  /// The title is still too long at the minimum scale and is ellipsized.
  final bool truncated;
}

/// Measures [title] once per card layout.
///
/// The title keeps its size while it fits in [kContinueReadingTitleMaxLines]
/// lines; otherwise it shrinks, down to [kContinueReadingTitleMinFontScale],
/// until it does. Only a title that overflows even then is ellipsized.
ContinueReadingTitleLayout resolveContinueReadingTitleLayout({
  required String title,
  required TextStyle style,
  required TextScaler textScaler,
  required TextDirection textDirection,
  required double maxWidth,
  Locale? locale,
}) {
  final painter = TextPainter(
    text: TextSpan(text: title, style: style),
    textDirection: textDirection,
    textScaler: textScaler,
    locale: locale,
    maxLines: kContinueReadingTitleMaxLines,
  );
  try {
    var scale = 1.0;
    while (true) {
      painter
        ..text = TextSpan(text: title, style: libraryTitleStyle(style, scale))
        ..layout(maxWidth: maxWidth);
      final fits = !painter.didExceedMaxLines;
      if (fits || scale <= kContinueReadingTitleMinFontScale) {
        return ContinueReadingTitleLayout(fontScale: scale, truncated: !fits);
      }
      scale = math.max(
        kContinueReadingTitleMinFontScale,
        scale - _fontScaleStep,
      );
    }
  } finally {
    painter.dispose();
  }
}
