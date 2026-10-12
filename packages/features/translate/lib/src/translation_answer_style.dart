part of 'translate_sheet.dart';

/// Answers longer than this many graphemes are body text even when they
/// would fit two heading lines on a wide screen.
const _maxHeadingGraphemes = 48;

/// Body style of answers too long for a heading.
TextStyle _answerBodyStyle(BuildContext context) =>
    context.text.bodyLarge.copyWith(letterSpacing: 0);

/// Style of an answer in a `SelectableText` box [boxWidth] wide: the serif
/// heading when [text] has at most 48 graphemes and fits two lines,
/// [_answerBodyStyle] otherwise.
///
/// A heading shrinks just enough to keep its longest word whole at large
/// text sizes, never below metadata size.
TextStyle _answerHeadingStyle(
  BuildContext context,
  String text,
  double boxWidth,
) {
  if (text.characters.take(_maxHeadingGraphemes + 1).length >
      _maxHeadingGraphemes) {
    return _answerBodyStyle(context);
  }
  final heading = context.text.headlineSmall.copyWith(letterSpacing: 0);
  final direction = translationTextDirection(text);
  final painter = TextPainter(
    text: TextSpan(text: text, style: heading),
    textDirection: direction,
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 2,
  )..layout(maxWidth: boxWidth - appSelectableTextCaretMargin);
  final fits = !painter.didExceedMaxLines;
  painter.dispose();
  if (!fits) return _answerBodyStyle(context);
  return appFitSelectableText(
    context,
    heading,
    text: text,
    boxWidth: boxWidth,
    textDirection: direction,
  );
}
