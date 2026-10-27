import 'package:component_library/component_library.dart';
import 'package:contextual_translation_service/contextual_translation_service.dart';
import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:flutter/material.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:shared/shared.dart';

import 'translate_sheet.dart';
import 'translate_sheet_outcome.dart';

/// Opens another action for the same selection, such as a definition.
typedef TranslateFollowUpAction =
    Future<void> Function(BuildContext context, TextSelectionContext selection);

/// Reader plug-in for contextual translation of the current text selection.
class TranslateAction extends TextAction {
  TranslateAction({
    required this.translationService,
    required this.preferencesService,
    this.dictionaryRepository,
    this.onDefine,
  });

  final ContextualTranslationService translationService;
  final PreferencesService preferencesService;

  /// Keeps words the reader saves from the sheet; without it there is no
  /// Save.
  final DictionaryRepository? dictionaryRepository;

  /// Shows the definition of the same selection. Offered when a word is
  /// already in the target language, where a definition is what the reader
  /// wants. `routing.dart` passes the dictionary action here, so this
  /// package never imports it.
  final TranslateFollowUpAction? onDefine;

  @override
  String get label => 'Translate';

  @override
  String labelFor(BuildContext context) => context.l10n.translationAction;

  @override
  IconData get icon => AppIcons.translate;

  @override
  Future<void> onExecute(
    BuildContext context,
    TextSelectionContext selection,
  ) async {
    final onDefine = this.onDefine;
    final outcome = await showTranslateSheet(
      context,
      selection: selection,
      translationService: translationService,
      preferencesService: preferencesService,
      dictionaryRepository: dictionaryRepository,
      canDefine: onDefine != null,
    );
    // The sheet is closed by now; [context] belongs to the caller and opens
    // the definition in its place.
    if (outcome != TranslateSheetOutcome.define ||
        onDefine == null ||
        !context.mounted) {
      return;
    }
    await onDefine(context, selection);
  }
}
