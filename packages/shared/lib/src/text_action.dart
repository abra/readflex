import 'package:domain_models/domain_models.dart' show SourceType;
import 'package:flutter/widgets.dart';

/// Payload delivered to a [TextAction] when the user selects text in the
/// reader — the selected string plus enough positional metadata
/// (CFI range / scroll offset / page number) for the action to save an
/// anchor back to the source.
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

  /// Source type (book or article).
  final SourceType sourceType;

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

  /// Executes the action for the given text selection. Callers should
  /// `await` this to run side effects (e.g. refresh) after the sheet
  /// closes.
  Future<void> onExecute(BuildContext context, TextSelectionContext selection);
}
