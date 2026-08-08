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
/// to the reader. The regular reader flow saves immediately; the highlight
/// sheet remains available for a future edit / note experience.
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
    final anchor = _highlightTraceAnchor(selection.cfiRange);
    if (kDebugMode) {
      debugPrint(
        '[reader-highlight] repository-add-start '
        'source=${selection.sourceId} '
        'text="${_highlightTraceText(selection.selectedText)}" '
        'anchor=$anchor '
        'color=${color.name} '
        'replace=${selection.containedHighlightIds.length}',
      );
    }
    final highlight = await highlightRepository.addHighlight(
      sourceId: selection.sourceId,
      sourceType: selection.sourceType,
      text: selection.selectedText,
      color: color,
      cfiRange: selection.cfiRange,
      pageNumber: selection.pageNumber,
      scrollOffset: selection.scrollOffset,
      progress: selection.progress,
      chapterTitle: selection.chapterTitle,
      replaceHighlightIds: selection.containedHighlightIds,
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
