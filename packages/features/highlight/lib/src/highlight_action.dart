import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:highlight_repository/highlight_repository.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:shared/shared.dart';

/// Reader plug-in that lets the user save the currently selected text as a
/// [Highlight].
///
/// Registered in the composition root as one of the [TextAction]s passed
/// to the reader. Explicit action execution saves without opening a sheet;
/// palette changes alone only preview. The standalone sheet supports notes.
class HighlightAction extends ColorHighlightTextAction {
  HighlightAction({
    required this.highlightRepository,
  });

  final HighlightRepository highlightRepository;

  @override
  String get label => 'Highlight';

  @override
  String labelFor(BuildContext context) => context.l10n.highlightAction;

  @override
  IconData get icon => AppIcons.highlight;

  @override
  Future<void> onExecute(
    BuildContext context,
    TextSelectionContext selection,
  ) {
    return onExecuteWithColor(context, selection, HighlightColor.yellow);
  }

  @override
  Future<void> onExecuteWithColor(
    BuildContext context,
    TextSelectionContext selection,
    HighlightColor color,
  ) async {
    // One piece of text belongs to one highlight: a selection sharing text
    // with saved highlights saves their union and absorbs them (notes kept).
    final merge = selection.highlightMerge;
    final text = merge?.text ?? selection.selectedText;
    final cfiRange = merge?.cfiRange ?? selection.cfiRange;
    final anchor = _highlightTraceAnchor(cfiRange);
    if (kDebugMode) {
      debugPrint(
        '[reader-highlight] repository-add-start '
        'source=${selection.sourceId} '
        'text="${_highlightTraceText(text)}" '
        'anchor=$anchor '
        'color=${color.name} '
        'merge=${merge?.highlightIds.length ?? 0}',
      );
    }
    final highlight = await highlightRepository.addHighlight(
      sourceId: selection.sourceId,
      sourceType: selection.sourceType,
      text: text,
      color: color,
      cfiRange: cfiRange,
      pageNumber: selection.pageNumber,
      scrollOffset: selection.scrollOffset,
      progress: selection.progress,
      chapterTitle: selection.chapterTitle,
      replaceHighlightIds: merge?.highlightIds ?? const [],
    );
    if (kDebugMode) {
      debugPrint(
        '[reader-highlight] repository-add-success '
        'id=${highlight.id} '
        'source=${selection.sourceId} '
        'anchor=$anchor',
      );
    }
  }
}

String _highlightTraceText(String text) {
  final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  return normalized.length <= 48
      ? normalized
      : '${normalized.substring(0, 48)}...';
}

String _highlightTraceAnchor(String? cfiRange) {
  if (cfiRange == null || cfiRange.isEmpty) return 'none';
  return '${cfiRange.length}:'
      '${cfiRange.hashCode.toUnsigned(32).toRadixString(16)}';
}
