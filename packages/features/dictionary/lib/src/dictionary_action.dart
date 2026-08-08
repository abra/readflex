import 'package:component_library/component_library.dart';
import 'package:dictionary_service/dictionary_service.dart';
import 'package:flutter/material.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:shared/shared.dart';

import 'dictionary_sheet.dart';

class DictionaryAction extends TextAction {
  DictionaryAction({
    required this.systemDictionaryService,
    required this.dictionaryLookupService,
  });

  final SystemDictionaryService systemDictionaryService;
  final DictionaryLookupService dictionaryLookupService;

  @override
  String get label => 'Define';

  @override
  String labelFor(BuildContext context) => context.l10n.dictionaryAction;

  @override
  IconData get icon => AppIcons.dictionary;

  @override
  Future<void> onExecute(
    BuildContext context,
    TextSelectionContext selection,
  ) async {
    final term = selection.effectiveSelectedText.trim();
    if (term.isEmpty) return;
    final presented = await systemDictionaryService.showDefinition(term);
    if (presented || !context.mounted) return;
    await showDictionarySheet(
      context,
      selection: selection,
      dictionaryService: dictionaryLookupService,
    );
  }
}
