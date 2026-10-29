/// Text the user selected on the page. The anchor is an EPUB CFI or a
/// serialized article HTML position.
class ReaderSelection {
  const ReaderSelection({
    required this.text,
    this.normalizedText,
    this.selectionKind,
    this.contextText,
    this.markedContextText,
    this.normalizedMarkedContextText,
    this.cfiRange,
    this.normalizedCfiRange,
    this.position,
    this.scrollOffset,
    this.highlightMerge,
  });

  final String text;

  /// Selection expanded to complete word boundaries for lexical actions.
  final String? normalizedText;

  /// Selection shape, e.g. exact, partial_word, partial_span.
  final String? selectionKind;

  /// Surrounding sentence/paragraph excerpt for lexical text actions.
  final String? contextText;

  /// Same excerpt with the exact selected range wrapped in [[...]].
  final String? markedContextText;

  /// Same excerpt with the normalized lexical range wrapped in [[...]].
  final String? normalizedMarkedContextText;

  /// Exact selection anchor (EPUB CFI or article HTML position).
  final String? cfiRange;

  /// Anchor of the normalized lexical selection.
  final String? normalizedCfiRange;

  /// Normalized viewport rectangle of the selected text.
  final ReaderSelectionPosition? position;

  /// Scroll offset of an article when the text was selected.
  final double? scrollOffset;

  /// Saved highlights sharing text with the selection, merged into one range;
  /// `null` when the selection touches no saved highlight.
  final ReaderHighlightMerge? highlightMerge;
}

/// Merge plan for a selection: the union of the selection and every saved
/// highlight sharing text with it. [cfiRange] is a saved highlight's own
/// anchor when the union equals its range.
class ReaderHighlightMerge {
  const ReaderHighlightMerge({
    required this.cfiRange,
    required this.text,
    required this.highlightIds,
  });

  final String cfiRange;
  final String text;

  /// Absorbed saved highlights, in document order.
  final List<String> highlightIds;
}

/// Selection bounds as fractions of the page surface: 0..1 inside it, past
/// that for a selection that runs off the page.
class ReaderSelectionPosition {
  const ReaderSelectionPosition({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ReaderSelectionPosition &&
            other.left == left &&
            other.top == top &&
            other.right == right &&
            other.bottom == bottom;
  }

  @override
  int get hashCode => Object.hash(left, top, right, bottom);
}

/// The user tapped a saved highlight on the page.
class ReaderHighlightTap {
  const ReaderHighlightTap({
    required this.highlightId,
    this.position,
    this.contextText,
  });

  final String highlightId;
  final ReaderSelectionPosition? position;
  final String? contextText;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ReaderHighlightTap &&
            other.highlightId == highlightId &&
            other.position == position &&
            other.contextText == contextText;
  }

  @override
  int get hashCode => Object.hash(highlightId, position, contextText);
}

/// An area of an image page (comic, PDF) as fractions of the page.
class ReaderImageAreaRect {
  const ReaderImageAreaRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final double x;
  final double y;
  final double width;
  final double height;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ReaderImageAreaRect &&
            other.x == x &&
            other.y == y &&
            other.width == width &&
            other.height == height;
  }

  @override
  int get hashCode => Object.hash(x, y, width, height);
}
