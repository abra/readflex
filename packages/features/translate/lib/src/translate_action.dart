import 'package:component_library/component_library.dart';
import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:flutter/material.dart';
import 'package:fsrs_repository/fsrs_repository.dart';
import 'package:shared/shared.dart';
import 'package:translation_service/translation_service.dart';

import 'translate_sheet.dart';

/// TextAction implementation that opens the translate bottom sheet.
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
