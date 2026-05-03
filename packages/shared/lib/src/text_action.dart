import 'package:domain_models/domain_models.dart' show SourceType;
import 'package:flutter/widgets.dart';

/// Payload delivered to a [TextAction] when the user selects text in the
/// reader — the selected string plus an EPUB CFI range for the action to
/// save an anchor back to the source.
///
/// [pageNumber] and [scrollOffset] are vestigial from the removed article
/// reader; they are always `null` for current sources. [sourceType] is
/// likewise legacy — `SourceType` only has `book` since articles were
/// dropped.
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

  /// ID of the book being read.
  final String sourceId;

  /// Always [SourceType.book] — kept for the existing API shape.
  final SourceType sourceType;

  /// CFI range for the EPUB selection.
  final String? cfiRange;

  /// Vestigial — was used by the removed article reader.
  final int? pageNumber;

  /// Vestigial — was used by the removed article reader.
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
