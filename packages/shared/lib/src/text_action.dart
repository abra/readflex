import 'package:domain_models/domain_models.dart'
    show HighlightColor, SourceType;
import 'package:flutter/widgets.dart';

/// Payload delivered to a [TextAction] when the user selects text in the
/// reader — the selected string plus a CFI range for the action to save an
/// anchor back to the source.
///
/// [contextText] is the surrounding sentence/paragraph excerpt supplied by
/// the reader runtime for context-aware actions. [pageNumber] and
/// [scrollOffset] are legacy optional position fields. Current text-reader
/// selections primarily use [cfiRange].
class TextSelectionContext {
  const TextSelectionContext({
    required this.selectedText,
    required this.sourceId,
    required this.sourceType,
    this.normalizedSelectedText,
    this.selectionKind,
    this.contextText,
    this.markedContextText,
    this.normalizedMarkedContextText,
    this.cfiRange,
    this.normalizedCfiRange,
    this.pageNumber,
    this.scrollOffset,
  });

  /// The exact text the user selected.
  final String selectedText;

  /// Selection expanded to complete word boundaries for lexical actions.
  final String? normalizedSelectedText;

  /// Reader-side selection shape, e.g. exact, partial_word, partial_span.
  final String? selectionKind;

  /// ID of the reading source.
  final String sourceId;

  /// Source type used by actions that persist source-scoped rows.
  final SourceType sourceType;

  /// Surrounding sentence/paragraph excerpt for context-aware actions.
  final String? contextText;

  /// Same excerpt with the exact selected range wrapped in [[...]].
  final String? markedContextText;

  /// Same excerpt with the normalized lexical range wrapped in [[...]].
  final String? normalizedMarkedContextText;

  /// Text that an action should use when selection was partial.
  String get effectiveSelectedText {
    final normalized = normalizedSelectedText?.trim();
    return normalized == null || normalized.isEmpty ? selectedText : normalized;
  }

  /// Marked context that an action should use when selection was partial.
  String? get effectiveMarkedContextText {
    final normalized = normalizedMarkedContextText?.trim();
    return normalized == null || normalized.isEmpty
        ? markedContextText
        : normalized;
  }

  /// CFI range for the text-reader selection.
  final String? cfiRange;

  /// CFI range for [normalizedSelectedText] when the reader expanded a partial
  /// selection to complete lexical boundaries.
  final String? normalizedCfiRange;

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

/// Text action that can save a highlight with a caller-selected color.
///
/// Reader UI uses this specialized contract to render a compact highlight
/// popup without depending on the concrete highlight feature package.
abstract class ColorHighlightTextAction extends TextAction {
  Future<void> onExecuteWithColor(
    BuildContext context,
    TextSelectionContext selection,
    HighlightColor color,
  );
}
