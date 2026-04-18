import 'package:component_library/component_library.dart';
import 'package:flashcard_repository/flashcard_repository.dart';
import 'package:flutter/material.dart';
import 'package:fsrs_repository/fsrs_repository.dart';
import 'package:shared/shared.dart';

import 'flashcard_sheet.dart';

/// TextAction implementation that opens the flashcard bottom sheet.
class FlashcardAction extends TextAction {
  FlashcardAction({
    required this.flashcardRepository,
    required this.fsrsRepository,
  });

  final FlashcardRepository flashcardRepository;
  final FsrsRepository fsrsRepository;

  @override
  String get label => 'Flashcard';

  @override
  IconData get icon => AppIcons.flashcard;

  @override
  Future<void> onExecute(
    BuildContext context,
    TextSelectionContext selection,
  ) {
    return showFlashcardSheet(
      context,
      flashcardRepository: flashcardRepository,
      fsrsRepository: fsrsRepository,
      selection: selection,
    );
  }
}
