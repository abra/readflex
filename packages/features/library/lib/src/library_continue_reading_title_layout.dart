import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'library_title_layout.dart';

const int _fitSearchSteps = 16;

/// How the Continue reading card fits its title.
class ContinueReadingTitleLayout {
  const ContinueReadingTitleLayout({
    required this.fontScale,
    required this.maxLines,
  });

  /// Multiplier for the title role's font size.
  final double fontScale;

  /// Lines that fit the available cover height at [fontScale].
  final int maxLines;
}

/// Keeps the full title inside both bounds at the largest fitting font size.
/// Short titles keep the theme's size; longer titles wrap and scale down.
ContinueReadingTitleLayout resolveContinueReadingTitleLayout({
  required String title,
  required TextStyle style,
  required TextScaler textScaler,
  required TextDirection textDirection,
  required double maxWidth,
  required double maxHeight,
  Locale? locale,
}) {
  final painter = TextPainter(
    text: TextSpan(text: title, style: style),
    textDirection: textDirection,
    textScaler: textScaler,
    locale: locale,
  );
  try {
    bool fits(double scale) {
      painter.text = TextSpan(
        text: title,
        style: libraryTitleStyle(style, scale),
      );
      final lineHeight = painter.preferredLineHeight;
      painter
        ..maxLines = lineHeight > 0
            ? math.max(1, (maxHeight / lineHeight).floor())
            : null
        ..layout(maxWidth: maxWidth);
      return !painter.didExceedMaxLines &&
          painter.height <= maxHeight &&
          painter.computeLineMetrics().every((line) => line.width <= maxWidth);
    }

    if (fits(1)) {
      return ContinueReadingTitleLayout(
        fontScale: 1,
        maxLines: painter.maxLines ?? 1,
      );
    }
    var lower = 0.0;
    var upper = 1.0;
    for (var step = 0; step < _fitSearchSteps; step++) {
      final candidate = (lower + upper) / 2;
      if (fits(candidate)) {
        lower = candidate;
      } else {
        upper = candidate;
      }
    }
    final scale = lower > 0 ? lower : upper;
    fits(scale);
    return ContinueReadingTitleLayout(
      fontScale: scale,
      maxLines: painter.maxLines ?? 1,
    );
  } finally {
    painter.dispose();
  }
}
