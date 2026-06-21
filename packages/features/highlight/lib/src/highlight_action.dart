import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:highlight_repository/highlight_repository.dart';
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
  ) {
    return highlightRepository.addHighlight(
      sourceId: selection.sourceId,
      sourceType: selection.sourceType,
      text: selection.selectedText,
      color: color,
      cfiRange: selection.cfiRange,
      pageNumber: selection.pageNumber,
      scrollOffset: selection.scrollOffset,
      progress: selection.progress,
      chapterTitle: selection.chapterTitle,
    );
  }
}
