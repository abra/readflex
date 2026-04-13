import 'package:component_library/component_library.dart';
import 'package:flashcard_repository/flashcard_repository.dart';
import 'package:flutter/material.dart';
import 'package:shared/shared.dart';

import 'flashcard_sheet.dart';

/// TextAction implementation that opens the flashcard bottom sheet.
class FlashcardAction extends TextAction {
  FlashcardAction({required this.flashcardRepository});

  final FlashcardRepository flashcardRepository;

  @override
  String get label => 'Flashcard';

  @override
  IconData get icon => AppIcons.flashcard;

  @override
  void onExecute(BuildContext context, TextSelectionContext selection) {
    showFlashcardSheet(
      context,
      flashcardRepository: flashcardRepository,
      selection: selection,
    );
  }
}
