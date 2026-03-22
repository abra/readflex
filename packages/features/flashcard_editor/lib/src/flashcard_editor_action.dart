import 'package:flashcard_repository/flashcard_repository.dart';
import 'package:flutter/material.dart';
import 'package:shared/shared.dart';

import 'flashcard_editor_sheet.dart';

/// TextAction implementation that opens the flashcard editor bottom sheet.
class FlashcardEditorAction extends TextAction {
  FlashcardEditorAction({required this.flashcardRepository});

  final FlashcardRepository flashcardRepository;

  @override
  String get label => 'Flashcard';

  @override
  IconData get icon => Icons.style;

  @override
  void onExecute(BuildContext context, TextSelectionContext selection) {
    showFlashcardEditorSheet(
      context,
      flashcardRepository: flashcardRepository,
      selection: selection,
    );
  }
}
