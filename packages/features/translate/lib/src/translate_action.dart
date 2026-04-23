import 'package:component_library/component_library.dart';
import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:flutter/material.dart';
import 'package:fsrs_repository/fsrs_repository.dart';
import 'package:shared/shared.dart';
import 'package:translation_service/translation_service.dart';

import 'translate_sheet.dart';

/// Reader plug-in that translates the currently selected text and lets
/// the user save it to the dictionary.
///
/// Registered in the composition root as one of the [TextAction]s passed
/// to the reader — appears in the reader's text-selection context panel
/// with the "Translate" label. Tapping it opens [showTranslateSheet].
class TranslateAction extends TextAction {
  TranslateAction({
    required this.translationService,
    required this.dictionaryRepository,
    required this.fsrsRepository,
  });

  final TranslationService translationService;
  final DictionaryRepository dictionaryRepository;
  final FsrsRepository fsrsRepository;

  @override
  String get label => 'Translate';

  @override
  IconData get icon => AppIcons.translate;

  @override
  Future<void> onExecute(
    BuildContext context,
    TextSelectionContext selection,
  ) {
    return showTranslateSheet(
      context,
      translationService: translationService,
      dictionaryRepository: dictionaryRepository,
      fsrsRepository: fsrsRepository,
      selection: selection,
    );
  }
}
