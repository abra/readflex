import 'package:component_library/component_library.dart';
import 'package:contextual_translation_service/contextual_translation_service.dart';
import 'package:flutter/material.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:shared/shared.dart';

import 'translate_sheet.dart';

/// Reader plug-in for contextual translation of the current text selection.
class TranslateAction extends TextAction {
  TranslateAction({
    required this.translationService,
    required this.preferencesService,
  });

  final ContextualTranslationService translationService;
  final PreferencesService preferencesService;

  @override
  String get label => 'Translate';

  @override
  String labelFor(BuildContext context) => _stringsFor(context).actionLabel;

  @override
  IconData get icon => AppIcons.language;

  @override
  Future<void> onExecute(BuildContext context, TextSelectionContext selection) {
    return showTranslateSheet(
      context,
      selection: selection,
      translationService: translationService,
      preferencesService: preferencesService,
    );
  }
}

_TranslateActionStrings _stringsFor(BuildContext context) {
  final code = Localizations.localeOf(context).languageCode;
  return switch (code) {
    'ru' => const _TranslateActionStrings(actionLabel: 'Перевести'),
    _ => const _TranslateActionStrings(actionLabel: 'Translate'),
  };
}

class _TranslateActionStrings {
  const _TranslateActionStrings({required this.actionLabel});

  final String actionLabel;
}
