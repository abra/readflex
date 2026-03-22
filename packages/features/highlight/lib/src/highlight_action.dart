import 'package:flutter/material.dart';
import 'package:highlight_repository/highlight_repository.dart';
import 'package:shared/shared.dart';

import 'highlight_sheet.dart';

/// TextAction implementation that opens the highlight bottom sheet.
class HighlightAction extends TextAction {
  HighlightAction({required this.highlightRepository});

  final HighlightRepository highlightRepository;

  @override
  String get label => 'Highlight';

  @override
  IconData get icon => Icons.highlight;

  @override
  void onExecute(BuildContext context, TextSelectionContext selection) {
    showHighlightSheet(
      context,
      highlightRepository: highlightRepository,
      selection: selection,
    );
  }
}
