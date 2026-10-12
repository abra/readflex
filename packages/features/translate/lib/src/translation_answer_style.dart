import 'package:component_library/component_library.dart';
import 'package:flutter/widgets.dart';

import 'translation_text_direction.dart';

/// Answers and selected phrases longer than this many graphemes are body
/// text even when they would fit two heading lines on a wide screen.
const _maxHeadingGraphemes = 48;

/// Body style of answers too long for a heading.
TextStyle translationBodyStyle(BuildContext context) =>
    context.text.bodyLarge.copyWith(letterSpacing: 0);

/// Style of a short answer or selected phrase in a box [width] wide: the
/// serif heading when [text] has at most 48 graphemes and fits two lines,
/// [translationBodyStyle] otherwise.
///
/// A heading shrinks just enough to keep its longest word whole at large
/// text sizes, never below metadata size.
TextStyle translationHeadingStyle(
  BuildContext context,
  String text,
  double width,
) {
  if (text.characters.take(_maxHeadingGraphemes + 1).length >
      _maxHeadingGraphemes) {
    return translationBodyStyle(context);
  }
  final heading = context.text.headlineSmall.copyWith(letterSpacing: 0);
  final textScaler = MediaQuery.textScalerOf(context);
  final direction = translationTextDirection(text);
  final textWidth = width - appSelectableTextCaretMargin;
  final painter = TextPainter(
    text: TextSpan(text: text, style: heading),
    textDirection: direction,
    textScaler: textScaler,
    maxLines: 2,
  )..layout(maxWidth: textWidth);
  final fits = !painter.didExceedMaxLines;
  painter.dispose();
  if (!fits) return translationBodyStyle(context);
  return translationWordFit(context, text, heading, textWidth);
}

/// [style] shrunk so that the longest word of [text] fits [textWidth],
/// never below metadata size.
TextStyle translationWordFit(
  BuildContext context,
  String text,
  TextStyle style,
  double textWidth,
) => appFitLongestWord(
  style,
  text: text,
  maxWidth: textWidth,
  minFontSize: context.text.bodyMedium.fontSize!,
  textScaler: MediaQuery.textScalerOf(context),
  textDirection: translationTextDirection(text),
  locale: Localizations.maybeLocaleOf(context),
);
