import 'dart:io';

import 'package:component_library/component_library.dart';
import 'package:contextual_translation_service/contextual_translation_service.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:shared/shared.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:translate/translate.dart';

import '../test/support/native_screenshots.dart';
import '../test/support/ui_test_driver.dart';
import '../test/support/ui_test_services.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  for (final example in [
    (
      name: 'symbols',
      word: 'paper',
      pronunciation: '/\u02C8pe\u026Ap\u0259/',
      partOfSpeech: 'noun',
      partOfSpeechLabel: 'Noun',
      wordTranslation: 'Papier',
      base: 'Papier; Dokument',
      sentence: '\u267E This book is printed on acid-free paper.',
      marked: '\u267E This book is printed on acid-free [[paper]].',
      sentenceTranslation:
          '\u267E Dieses Buch ist auf säurefreiem Papier gedruckt.',
      expression: null,
    ),
    (
      name: 'word',
      word: 'power',
      pronunciation: '/ˈpaʊər/',
      partOfSpeech: 'noun',
      partOfSpeechLabel: 'Noun',
      wordTranslation: 'Strom',
      base: 'Kraft',
      sentence: 'The battery supplies power to the devices.',
      marked: 'The battery supplies [[power]] to the devices.',
      sentenceTranslation: 'Der Akku versorgt die Geraete mit Strom.',
      expression: null,
    ),
    (
      name: 'expression',
      word: 'into',
      pronunciation: '/ˈɪntuː/',
      partOfSpeech: 'preposition',
      partOfSpeechLabel: 'Preposition',
      wordTranslation: 'in',
      base: 'in, hinein',
      sentence: 'This service falls into the same category.',
      marked: 'This service falls [[into]] the same category.',
      sentenceTranslation: 'Dieser Dienst gehört zur gleichen Kategorie.',
      expression: const ContextualTranslationExpression(
        text: 'falls into',
        translation: 'gehört zu',
      ),
    ),
    (
      name: 'rather',
      word: 'rather',
      pronunciation: '/ˈrɑːðə/',
      partOfSpeech: 'adverb',
      partOfSpeechLabel: 'Adverb',
      wordTranslation: 'eher',
      base: 'eher; ziemlich',
      sentence: 'She walked rather than waited for the bus.',
      marked: 'She walked [[rather]] than waited for the bus.',
      sentenceTranslation: 'Sie ging zu Fuß, anstatt auf den Bus zu warten.',
      expression: const ContextualTranslationExpression(
        text: 'rather than',
        translation: 'anstatt',
      ),
    ),
  ]) {
    testWidgets(
      'translation ${example.name}, copy and language change on device',
      (tester) async {
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
          (value) => value.copyWith(translationTargetLanguageCode: 'de'),
        );
        final service = FixtureTranslation(
          primaryTranslation: example.wordTranslation,
          baseTranslation: example.base,
          expression: example.expression,
          sentenceTranslation: example.sentenceTranslation,
          analysis: ContextualTranslationAnalysis(
            surfaceForm: example.word,
            lemma: example.word,
            pronunciation: example.pronunciation,
            partOfSpeech: example.partOfSpeech,
            expressionType: 'word',
          ),
        );
        // Use the device viewport and native clipboard, but no live provider or user data.
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            localizationsDelegates:
                ReadflexLocalizations.localizationsDelegates,
            supportedLocales: ReadflexSupportedLocales.locales,
            locale: const Locale('en'),
            home: const Scaffold(),
          ),
        );
        showTranslateSheet(
          tester.element(find.byType(Scaffold)),
          selection: TextSelectionContext(
            selectedText: example.word,
            contextText: example.sentence,
            markedContextText: example.marked,
            sourceId: 'fixture',
            sourceType: SourceType.book,
            sourceLanguageHint: 'en',
          ),
          translationService: service,
          preferencesService: preferences,
        );
        final primaryText =
            example.expression?.translation ?? example.wordTranslation;
        await waitForUi(
          tester,
          () => find.text(primaryText).evaluate().isNotEmpty,
          description: 'word translation',
        );
        expect(find.text(example.pronunciation).hitTestable(), findsOneWidget);
        expect(find.text(example.partOfSpeechLabel), findsOneWidget);
        expect(find.text(example.word), findsOneWidget);
        if (example.expression case final expression?) {
          expect(find.text(expression.text).hitTestable(), findsOneWidget);
          expect(find.text('In this context'), findsOneWidget);
        }
        final base = find.byKey(const ValueKey('translation-base-result'));
        expect(base.hitTestable(), findsOneWidget);
        expect(find.byType(ExpansionTile), findsNothing);
        await tester.pump(const Duration(milliseconds: 350));
        if (Platform.isAndroid) {
          // The previous case's native clipboard overlay is outside Flutter.
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(seconds: 7)),
          );
          await captureAndroidScreenshot('translation-${example.name}');
        } else {
          await binding.takeScreenshot('translation-${example.name}');
        }
        for (final entry in {
          'primary': primaryText,
          'base': example.base,
        }.entries) {
          final copy = find.byKey(ValueKey('translation-${entry.key}-copy'));
          await tester.ensureVisible(copy);
          await tapUi(tester, copy);
          expect(
            (await Clipboard.getData(Clipboard.kTextPlain))?.text,
            entry.value,
          );
        }
        expect(service.requests, hasLength(1));
        final language = find.byKey(
          const ValueKey('translation-target-language'),
        );
        await tester.ensureVisible(language);
        await tapUi(tester, language);
        await tapUi(tester, find.text('English').hitTestable().last);
        await waitForUi(
          tester,
          () =>
              service.requests.length == 2 &&
              find.text(primaryText).evaluate().isNotEmpty,
          description: 'changed target language',
        );
        expect(service.requests.last.targetLanguage, 'en');
        expect(service.requests.last.selection.text, example.word);
        expect(find.text(example.pronunciation), findsOneWidget);
        expect(base, findsOneWidget);
        binding.reportData ??= {};
        binding.reportData!.addAll({
          'platform': Platform.operatingSystem,
          'requests': service.requests.length,
        });
        await tester.pumpWidget(const SizedBox.shrink());
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  }
}
