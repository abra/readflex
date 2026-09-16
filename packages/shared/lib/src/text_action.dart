import 'package:domain_models/domain_models.dart'
    show HighlightColor, SourceType;
import 'package:flutter/widgets.dart';

/// Payload delivered to a [TextAction] when the user selects text in the
/// reader: selected text plus an opaque anchor back to the source. Books use
/// EPUB CFI; articles use a serialized `readflex-html-position:` anchor.
///
/// [contextText] is the surrounding sentence/paragraph excerpt supplied by
/// the reader runtime for context-aware actions. [progress] and [chapterTitle]
/// describe the reader location at selection time; [pageNumber] and
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
    this.progress,
    this.chapterTitle,
    this.sourceLanguageHint,
    this.containedHighlightIds = const [],
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
    return compatibleNormalizedSelectedText ?? selectedText;
  }

  /// Normalized text only when it is a genuine expansion of the exact range.
  ///
  /// This rejects stale reader snapshots, for example an old single-word
  /// normalization paired with a newer multi-word exact selection.
  String? get compatibleNormalizedSelectedText {
    final exact = _collapseSelectionWhitespace(selectedText);
    final normalized = _collapseSelectionWhitespace(
      normalizedSelectedText ?? '',
    );
    if (exact.isEmpty || normalized.isEmpty || !normalized.contains(exact)) {
      return null;
    }
    return normalized;
  }

  /// Marked context that an action should use when selection was partial.
  String? get effectiveMarkedContextText {
    if (compatibleNormalizedSelectedText == null) return markedContextText;
    final normalized = normalizedMarkedContextText?.trim();
    return normalized == null || normalized.isEmpty
        ? markedContextText
        : normalized;
  }

  /// Exact selection anchor: EPUB CFI or serialized article HTML position.
  final String? cfiRange;

  /// Anchor for [normalizedSelectedText] when the reader expanded a partial
  /// selection to complete lexical boundaries.
  final String? normalizedCfiRange;

  /// Legacy optional page position.
  final int? pageNumber;

  /// Legacy optional scroll position.
  final double? scrollOffset;

  /// Normalized reading progress at selection time.
  final double? progress;

  /// Visible chapter title at selection time.
  final String? chapterTitle;

  /// Best-known source language for the document, if the reader has one.
  ///
  /// Text actions can pass it as a hint while still allowing their own service
  /// to auto-detect the final language per selection.
  final String? sourceLanguageHint;

  /// Saved highlights fully contained in the selection, including equal ranges.
  final List<String> containedHighlightIds;
}

String _collapseSelectionWhitespace(String value) =>
    value.replaceAll(RegExp(r'\s+'), ' ').trim();

/// Contract for reader context-panel actions.
///
/// Each action appears as a button in the reader's context panel
/// when the user selects text. The reader knows nothing about
/// specific features — it just calls [onExecute].
///
/// Hosts should resolve the selection and dismiss transient context UI before
/// invoking an action from a [BuildContext] that remains mounted while any
/// modal or platform surface is open.
abstract class TextAction {
  String get label;

  String labelFor(BuildContext context) => label;

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
