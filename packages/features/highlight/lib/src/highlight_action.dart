import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:highlight_repository/highlight_repository.dart';
import 'package:shared/shared.dart';

import 'highlight_sheet.dart';

/// Reader plug-in that lets the user save the currently selected text as a
/// [Highlight].
///
/// Registered in the composition root as one of the [TextAction]s passed
/// to the reader — appears in the reader's text-selection context panel
/// with the "Highlight" label. Tapping it opens [showHighlightSheet].
class HighlightAction extends TextAction {
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
    return showHighlightSheet(
      context,
      highlightRepository: highlightRepository,
      selection: selection,
    );
  }
}
