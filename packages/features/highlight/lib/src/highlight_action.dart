import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:fsrs_repository/fsrs_repository.dart';
import 'package:highlight_repository/highlight_repository.dart';
import 'package:shared/shared.dart';

import 'highlight_sheet.dart';

/// TextAction implementation that opens the highlight bottom sheet.
class HighlightAction extends TextAction {
  HighlightAction({
    required this.highlightRepository,
    required this.fsrsRepository,
  });

  final HighlightRepository highlightRepository;
  final FsrsRepository fsrsRepository;

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
      fsrsRepository: fsrsRepository,
      selection: selection,
    );
  }
}
