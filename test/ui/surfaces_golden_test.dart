import 'dart:async';

import 'package:component_library/component_library.dart';
import 'package:contextual_translation_service/contextual_translation_service.dart';
import 'package:dictionary/dictionary.dart';
import 'package:dictionary_service/dictionary_service.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:import_flow/import_flow.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:reader/src/reader_highlight_controls.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:shared/shared.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:translate/translate.dart';

import '../support/reading_fixture.dart';
import '../support/ui_test_services.dart';
import 'golden_support.dart';

void main() {
  setUpAll(loadUiFonts);
  for (final profile in VisualProfile.values) {
    testWidgets('sheets and text tools ${profile.name}', (tester) async {
      final previousPlatform = SharedPreferencesAsyncPlatform.instance;
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      addTearDown(
        () => SharedPreferencesAsyncPlatform.instance = previousPlatform,
      );
      final preferences = await PreferencesService.create(
        supportedCodes: ['en', 'de', 'ar'],
      );
      addTearDown(preferences.dispose);
      await preferences.update(
        (p) => p.copyWith(translationTargetLanguageCode: 'de'),
      );
      final searchController = TextEditingController(text: 'portable power');
      addTearDown(searchController.dispose);
      const selection = TextSelectionContext(
        selectedText: ReadingFixture.phrase,
        contextText: ReadingFixture.sentence,
        markedContextText: 'The [[power bank]] keeps devices running.',
        sourceId: 'fixture',
        sourceType: SourceType.book,
        sourceLanguageHint: 'en',
      );
      Future<void> sheet(
        String name,
        void Function(BuildContext) open, {
        bool settle = true,
      }) async {
        late BuildContext sheetContext;
        await pumpGoldenSurface(
          tester,
          profile,
          (context) {
            sheetContext = context;
            return const Scaffold();
          },
        );
        open(sheetContext);
        await tester.pump();
        if (settle) {
          await tester.pumpAndSettle();
        } else {
          await tester.pump(const Duration(milliseconds: 350));
        }
        await expectUiGolden(tester, profile, name);
      }

      await sheet(
        'translation',
        (context) => showTranslateSheet(
          context,
          selection: selection,
          translationService: FixtureTranslation(),
          preferencesService: preferences,
        ),
      );
      await tester.tap(
        find.byKey(const ValueKey('translation-source-language')),
      );
      await tester.pumpAndSettle();
      await expectUiGolden(tester, profile, 'translation-language-menu');
      await sheet(
        'translation-details-collapsed',
        (context) => showTranslateSheet(
          context,
          selection: selection,
          translationService: FixtureTranslation(includeLexicalDetails: true),
          preferencesService: preferences,
        ),
      );
      final details = find.byType(ExpansionTile);
      await tester.ensureVisible(details);
      await tester.tap(details);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Ersatzakku'));
      await tester.pumpAndSettle();
      await expectUiGolden(tester, profile, 'translation-details-expanded');
      await sheet(
        'translation-error',
        (context) => showTranslateSheet(
          context,
          selection: selection,
          translationService: FixtureTranslation()
            ..failure = ContextualTranslationFailureReason.network,
          preferencesService: preferences,
        ),
      );
      final pending = Completer<void>();
      await sheet(
        'translation-loading',
        (context) => showTranslateSheet(
          context,
          selection: selection,
          translationService: FixtureTranslation()..pending = pending,
          preferencesService: preferences,
        ),
        settle: false,
      );
      pending.complete();
      await tester.pumpAndSettle();
      await sheet(
        'translation-word',
        (context) => showTranslateSheet(
          context,
          selection: const TextSelectionContext(
            selectedText: 'power',
            contextText: ReadingFixture.sentence,
            markedContextText: 'The [[power]] bank keeps devices running.',
            sourceId: 'fixture',
            sourceType: SourceType.book,
          ),
          translationService: FixtureTranslation(primaryTranslation: 'Strom'),
          preferencesService: preferences,
        ),
      );
      await sheet(
        'translation-text',
        (context) => showTranslateSheet(
          context,
          selection: const TextSelectionContext(
            selectedText: ReadingFixture.sentence,
            sourceId: 'fixture',
            sourceType: SourceType.book,
          ),
          translationService: FixtureTranslation(),
          preferencesService: preferences,
        ),
      );
      const dictionarySelection = TextSelectionContext(
        selectedText: 'power',
        sourceId: 'fixture',
        sourceType: SourceType.book,
      );
      await sheet(
        'definition',
        (context) => showDictionarySheet(
          context,
          selection: dictionarySelection,
          dictionaryService: FixtureDictionary(),
        ),
      );
      await sheet(
        'definition-contextual-expression',
        (context) => showDictionarySheet(
          context,
          selection: const TextSelectionContext(
            selectedText: 'shutting',
            contextText: 'The device saves power by shutting off its display.',
            sourceId: 'fixture',
            sourceType: SourceType.book,
          ),
          dictionaryService: FixtureDictionary(
            entries: const [
              DictionaryLexicalEntry(
                lemma: 'shut',
                pronunciation: '/shut/',
                partOfSpeech: 'verb',
                definitions: [
                  DictionaryDefinition(text: 'To close something.'),
                ],
              ),
              DictionaryLexicalEntry(
                lemma: 'shut off',
                partOfSpeech: 'phrasal verb',
                definitions: [
                  DictionaryDefinition(
                    text: 'To stop operating or to stop a supply.',
                    examples: ['Shut off the display to save power.'],
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      await sheet(
        'definition-not-found',
        (context) => showDictionarySheet(
          context,
          selection: selection,
          dictionaryService: FixtureDictionary()..unavailable = true,
        ),
      );
      await sheet(
        'import',
        (context) => showImportFlowSheet(
          context,
          onPickBookFile: () async => null,
          onImportBook: (_, {onProgress}) async => null,
          onImportArticle: (_, {onStage}) async => null,
        ),
      );
      await pumpGoldenSurface(
        tester,
        profile,
        (context) => Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SearchField(
                    controller: searchController,
                    hintText: context.l10n.librarySearchHint,
                    onChanged: (_) {},
                  ),
                  const SizedBox(height: 24),
                  ReaderHighlightControls(
                    selectedColor: HighlightColor.yellow,
                    busy: false,
                    readerTheme: ReaderThemePreset.paper.data,
                    dividerColor: context.colors.outlineVariant,
                    onColorChanged: (_) {},
                    actions: [
                      ReaderHighlightAction(
                        color: context.colors.primary,
                        icon: AppIcons.highlight,
                        tooltip: context.l10n.highlightAction,
                        onPressed: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await expectUiGolden(tester, profile, 'search-and-highlight');
      await tester.pumpWidget(const SizedBox.shrink());
    }, tags: ['golden']);
  }
}
