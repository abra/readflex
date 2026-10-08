import 'dart:ui' show TextRange;

/// Ends a sentence wherever it appears (CJK, Devanagari, Arabic marks).
const _closingTerminators = {'。', '！', '？', '।', '؟'};

/// Ends a sentence only before whitespace, so `3.5` or `e.g.x` stay whole.
const _spacedTerminators = {'.', '!', '?', '…'};

const _clauseSeparators = {',', ';', ':', '،', '؛', '、', '，', '；', '：'};

final _word = RegExp(r'\S+');

/// The phrase of a localized [text] that the onboarding page preview shows
/// highlighted.
///
/// Boundaries come from the text itself, never from fixed offsets: the first
/// sentence when more text follows it, else the first clause, else the first
/// half of the words, else the whole text. Every boundary sits next to a
/// basic-plane mark or whitespace, so a surrogate pair is never split.
TextRange onboardingHighlightRange(String text) {
  final start = text.length - text.trimLeft().length;
  final end = text.trimRight().length;
  if (start >= end) return TextRange.collapsed(start);

  // Only a terminator with text after it ends a *first* sentence.
  for (var i = start; i < end - 1; i++) {
    final char = text[i];
    if (_closingTerminators.contains(char) ||
        (_spacedTerminators.contains(char) && text[i + 1].trim().isEmpty)) {
      return TextRange(start: start, end: i + 1);
    }
  }
  for (var i = start + 1; i < end - 1; i++) {
    if (_clauseSeparators.contains(text[i])) {
      return TextRange(start: start, end: i);
    }
  }
  final words = _word.allMatches(text).toList();
  if (words.length > 1) {
    return TextRange(start: start, end: words[(words.length + 1) ~/ 2 - 1].end);
  }
  return TextRange(start: start, end: end);
}
