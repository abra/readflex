import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// Smallest title font relative to the theme role when a single word is
/// wider than the stacked row.
const double kLibraryTitleMinFontScale = 0.7;
const double _fontScaleStep = 0.05;
final _wordBreak = RegExp(r'\s+');

/// How the Library header fits its title beside the header actions.
class LibraryTitleLayout {
  const LibraryTitleLayout({
    required this.stacked,
    this.fontScale = 1,
    this.maxLines = 1,
  });

  static const inline = LibraryTitleLayout(stacked: false);

  /// Actions move to their own row above a full-width title.
  final bool stacked;

  /// Multiplier for the title role's font size.
  final double fontScale;

  /// `null` lets the title wrap further rather than truncate.
  final int? maxLines;
}

/// Measures [title] once per header layout.
///
/// The title stays on the action row when it fits in [inlineWidth]. Otherwise
/// it stacks below the actions with [stackedWidth], wraps to two lines, and
/// shrinks (down to [kLibraryTitleMinFontScale]) only while its widest word
/// or the two lines still overflow. It is never ellipsized.
LibraryTitleLayout resolveLibraryTitleLayout({
  required String title,
  required TextStyle style,
  required TextScaler textScaler,
  required TextDirection textDirection,
  required double inlineWidth,
  required double stackedWidth,
  Locale? locale,
}) {
  final painter = TextPainter(
    text: TextSpan(text: title, style: style),
    textDirection: textDirection,
    textScaler: textScaler,
    locale: locale,
    maxLines: 1,
  )..layout();
  try {
    if (painter.width <= inlineWidth) return LibraryTitleLayout.inline;

    var widestWord = '';
    var widestWordWidth = 0.0;
    for (final word in title.split(_wordBreak)) {
      if (word.isEmpty) continue;
      painter.text = TextSpan(text: word, style: style);
      painter.layout();
      if (painter.width > widestWordWidth) {
        widestWordWidth = painter.width;
        widestWord = word;
      }
    }

    var scale = widestWordWidth > stackedWidth
        ? math.max(kLibraryTitleMinFontScale, stackedWidth / widestWordWidth)
        : 1.0;
    while (true) {
      final scaled = libraryTitleStyle(style, scale);
      painter
        ..maxLines = 1
        ..text = TextSpan(text: widestWord, style: scaled)
        ..layout();
      final wordFits = painter.width <= stackedWidth;
      painter
        ..maxLines = 2
        ..text = TextSpan(text: title, style: scaled)
        ..layout(maxWidth: stackedWidth);
      final linesFit = !painter.didExceedMaxLines;
      if (wordFits && linesFit) {
        return LibraryTitleLayout(stacked: true, fontScale: scale, maxLines: 2);
      }
      if (scale <= kLibraryTitleMinFontScale) {
        return LibraryTitleLayout(
          stacked: true,
          fontScale: scale,
          maxLines: linesFit ? 2 : null,
        );
      }
      scale = math.max(kLibraryTitleMinFontScale, scale - _fontScaleStep);
    }
  } finally {
    painter.dispose();
  }
}

/// [style] with its font size multiplied by [fontScale].
TextStyle libraryTitleStyle(TextStyle style, double fontScale) {
  if (fontScale == 1) return style;
  return style.copyWith(fontSize: style.fontSize! * fontScale);
}
