import 'package:flutter/foundation.dart';

/// What saving a text selection as a highlight replaces.
///
/// One piece of text belongs to at most one highlight. When the selection
/// shares text with saved highlights, the reader runtime merges them into one
/// range: [cfiRange] and [text] describe that union, and [highlightIds] lists
/// every absorbed highlight in document order. When the union is exactly a
/// saved highlight's range (a selection inside it, or the same range), the
/// reader passes that highlight's own anchor and text, so saving recolours it
/// and keeps its identity instead of creating a twin.
///
/// Touching highlights that share no character are not merged.
@immutable
class HighlightMergeTarget {
  const HighlightMergeTarget({
    required this.cfiRange,
    required this.text,
    required this.highlightIds,
  });

  /// Anchor of the merged range: EPUB CFI or serialized article position.
  final String cfiRange;

  /// Text of the merged range, in the same form the reader stores for a
  /// plain selection.
  final String text;

  /// Saved highlights absorbed by the merge, in document order.
  final List<String> highlightIds;

  @override
  bool operator ==(Object other) =>
      other is HighlightMergeTarget &&
      other.cfiRange == cfiRange &&
      other.text == text &&
      listEquals(other.highlightIds, highlightIds);

  @override
  int get hashCode => Object.hash(cfiRange, text, Object.hashAll(highlightIds));

  @override
  String toString() =>
      'HighlightMergeTarget(highlightIds: $highlightIds, '
      'textLength: ${text.length})';
}
