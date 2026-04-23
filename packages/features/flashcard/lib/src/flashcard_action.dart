import 'package:component_library/component_library.dart';
import 'package:flashcard_repository/flashcard_repository.dart';
import 'package:flutter/material.dart';
import 'package:fsrs_repository/fsrs_repository.dart';
import 'package:shared/shared.dart';

import 'flashcard_sheet.dart';

/// Reader plug-in that lets the user turn the currently selected text into
/// a new [Flashcard].
///
/// Registered in the composition root as one of the [TextAction]s passed
/// to the reader — appears in the reader's text-selection context panel
/// with the "Flashcard" label. Tapping it opens [showFlashcardSheet].
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
