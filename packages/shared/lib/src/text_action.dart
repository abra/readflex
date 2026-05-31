import 'package:domain_models/domain_models.dart' show SourceType;
import 'package:flutter/widgets.dart';

/// Payload delivered to a [TextAction] when the user selects text in the
/// reader — the selected string plus a CFI range for the action to save an
/// anchor back to the source.
///
/// [pageNumber] and [scrollOffset] are legacy optional position fields.
/// Current text-reader selections primarily use [cfiRange].
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

  /// ID of the reading source.
  final String sourceId;

  /// Source type used by actions that persist source-scoped rows.
  final SourceType sourceType;

  /// CFI range for the text-reader selection.
  final String? cfiRange;

  /// Legacy optional page position.
  final int? pageNumber;

  /// Legacy optional scroll position.
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
