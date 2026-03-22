import 'package:flutter/widgets.dart';

/// Context passed to a [TextAction] when the user selects text in the reader.
class TextSelectionContext {
  const TextSelectionContext({
    required this.selectedText,
    required this.sourceId,
    required this.sourceType,
    this.cfiRange,
    this.pageNumber,
    this.scrollOffset,
  });

  /// The text the user selected.
  final String selectedText;

  /// ID of the book or article being read.
  final String sourceId;

  /// 'book' or 'article'.
  final String sourceType;

  /// CFI range for epub books.
  final String? cfiRange;

  /// Page number (if available).
  final int? pageNumber;

  /// Scroll offset for articles.
  final double? scrollOffset;
}

/// Contract for reader context-panel actions.
///
/// Each action appears as a button in the reader's context panel
/// when the user selects text. The reader knows nothing about
/// specific features — it just calls [onExecute].
abstract class TextAction {
  String get label;
  IconData get icon;
  void onExecute(BuildContext context, TextSelectionContext selection);
}
