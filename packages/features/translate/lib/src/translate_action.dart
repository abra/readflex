import 'package:component_library/component_library.dart';
import 'package:contextual_translation_service/contextual_translation_service.dart';
import 'package:flutter/material.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
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
  String labelFor(BuildContext context) => context.l10n.translationAction;

  @override
  IconData get icon => AppIcons.translate;

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
