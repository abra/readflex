import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:flutter/material.dart';
import 'package:shared/shared.dart';
import 'package:translation_service/translation_service.dart';

import 'translate_text_sheet.dart';

/// TextAction implementation that opens the translate bottom sheet.
class TranslateAction extends TextAction {
  TranslateAction({
    required this.translationService,
    required this.dictionaryRepository,
  });

  final TranslationService translationService;
  final DictionaryRepository dictionaryRepository;

  @override
  String get label => 'Translate';

  @override
  IconData get icon => Icons.translate;

  @override
  void onExecute(BuildContext context, TextSelectionContext selection) {
    showTranslateSheet(
      context,
      translationService: translationService,
      dictionaryRepository: dictionaryRepository,
      selection: selection,
    );
  }
}
