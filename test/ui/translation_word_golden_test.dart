import 'package:flutter/material.dart';
import 'package:contextual_translation_service/contextual_translation_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:domain_models/domain_models.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:shared/shared.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:translate/translate.dart';

import '../support/ui_test_services.dart';
import 'golden_support.dart';

void main() {
  setUpAll(loadUiFonts);
  for (final profile in VisualProfile.values) {
    testWidgets('word and contextual translation ${profile.name}', (
      tester,
    ) async {
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
      final service = FixtureTranslation(
        baseTranslation: 'Kraft',
        primaryTranslation: 'Strom',
        analysis: const ContextualTranslationAnalysis(
          surfaceForm: 'power',
          lemma: 'power',
          pronunciation: '/ˈpaʊər/',
          partOfSpeech: 'noun',
          expressionType: 'word',
        ),
      );
      late BuildContext sheetContext;
      await pumpGoldenSurface(tester, profile, (context) {
        sheetContext = context;
        return const Scaffold();
      });
      showTranslateSheet(
        sheetContext,
        selection: const TextSelectionContext(
          selectedText: 'power',
          contextText: 'The battery supplies power to the devices.',
          markedContextText: 'The battery supplies [[power]] to the devices.',
          sourceId: 'fixture',
          sourceType: SourceType.book,
          sourceLanguageHint: 'en',
        ),
        translationService: service,
        preferencesService: preferences,
      );
      await tester.pumpAndSettle();
      await expectUiGolden(tester, profile, 'translation-word-context');
      final contextAnswer = find.byKey(
        const ValueKey('translation-base-result'),
      );
      expect(contextAnswer, findsOneWidget);
      expect(find.byType(ExpansionTile), findsNothing);
      await tester.ensureVisible(contextAnswer);
      expect(contextAnswer.hitTestable(), findsOneWidget);
      expect(
        find.byKey(const ValueKey('translation-base-copy')).hitTestable(),
        findsOneWidget,
      );
      expect(service.requests, hasLength(1));
      expect(tester.takeException(), isNull);
    }, tags: ['golden']);

    for (final example in [
      (
        name: 'expression',
        word: 'into',
        pronunciation: '/ˈɪntuː/',
        partOfSpeech: 'preposition',
        base: 'в, внутрь',
        expression: 'falls into',
        translation: 'относится к',
        sentence: 'This service falls into the same category.',
        marked: 'This service falls [[into]] the same category.',
        sentenceTranslation: 'Этот сервис относится к той же категории.',
        explanation:
            'Здесь falls into означает принадлежность к категории, '
            'а не движение внутрь.',
        alternative: 'принадлежит к',
      ),
      (
        name: 'rather',
        word: 'rather',
        pronunciation: '/ˈrɑːðə/',
        partOfSpeech: 'adverb',
        base: 'скорее; довольно',
        expression: 'rather than',
        translation: 'вместо того чтобы',
        sentence: 'She walked rather than waited for the bus.',
        marked: 'She walked [[rather]] than waited for the bus.',
        sentenceTranslation:
            'Она пошла пешком вместо того, чтобы ждать автобус.',
        explanation:
            'Rather than противопоставляет два действия: '
            'она предпочла пойти пешком, а не ждать.',
        alternative: 'а не',
      ),
    ]) {
      testWidgets('contextual ${example.name} ${profile.name}', (tester) async {
        final previousPlatform = SharedPreferencesAsyncPlatform.instance;
        SharedPreferencesAsyncPlatform.instance =
            InMemorySharedPreferencesAsync.empty();
        addTearDown(
          () => SharedPreferencesAsyncPlatform.instance = previousPlatform,
        );
        final preferences = await PreferencesService.create(
          supportedCodes: ['en', 'ru', 'ar'],
        );
        addTearDown(preferences.dispose);
        await preferences.update(
          (p) => p.copyWith(translationTargetLanguageCode: 'ru'),
        );
        final service = FixtureTranslation(
          primaryTranslation: example.base,
          baseTranslation: example.base,
          explanation: example.explanation,
          alternatives: [
            ContextualTranslationAlternative(translation: example.alternative),
          ],
          expression: ContextualTranslationExpression(
            text: example.expression,
            translation: example.translation,
          ),
          sentenceTranslation: example.sentenceTranslation,
          analysis: ContextualTranslationAnalysis(
            surfaceForm: example.word,
            lemma: example.word,
            pronunciation: example.pronunciation,
            partOfSpeech: example.partOfSpeech,
            expressionType: 'word',
          ),
        );
        await pumpGoldenSurface(tester, profile, (_) => const Scaffold());
        showTranslateSheet(
          tester.element(find.byType(Scaffold)),
          selection: TextSelectionContext(
            selectedText: example.word,
            contextText: example.sentence,
            markedContextText: example.marked,
            sourceId: 'fixture',
            sourceType: SourceType.article,
            sourceLanguageHint: 'en',
          ),
          translationService: service,
          preferencesService: preferences,
        );
        await tester.pumpAndSettle();
        final l10n = ReadflexLocalizations.of(
          tester.element(find.byType(TranslateSheet)),
        )!;
        expect(find.text(l10n.translationInContext), findsOneWidget);
        expect(find.text(example.base), findsOneWidget);
        await expectUiGolden(tester, profile, 'translation-${example.name}');
        await tester.ensureVisible(find.byType(ExpansionTile));
        await tester.tap(find.byType(ExpansionTile));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.text(example.alternative),
        );
        await tester.pumpAndSettle();
        expect(find.text(example.alternative).hitTestable(), findsOneWidget);
        await expectUiGolden(
          tester,
          profile,
          'translation-${example.name}-details',
        );
        expect(find.text(example.base), findsOneWidget);
        expect(service.requests, hasLength(1));
        expect(tester.takeException(), isNull);
      }, tags: ['golden']);
    }
  }
}
