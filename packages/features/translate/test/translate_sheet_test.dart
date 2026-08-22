import 'package:component_library/component_library.dart';
import 'package:contextual_translation_service/contextual_translation_service.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:shared/shared.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:translate/translate.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets(
    'renders compact language selectors without visible From and To labels',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final preferences = await PreferencesService.create(
        supportedCodes: const ['en', 'ru'],
      );
      await preferences.update(
        (prefs) => prefs.copyWith(translationTargetLanguageCode: 'ru'),
      );

      await tester.pumpWidget(
        MaterialApp(
          supportedLocales: ReadflexSupportedLocales.locales,
          localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
          theme: AppTheme.light(),
          home: Scaffold(
            body: TranslateSheet(
              selection: _selection,
              translationService: _FakeTranslationService(),
              preferencesService: preferences,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('From'), findsNothing);
      expect(find.text('To'), findsNothing);
      expect(find.bySemanticsLabel('From'), findsOneWidget);
      expect(find.bySemanticsLabel('To'), findsOneWidget);

      final selectors = find.byType(DropdownButtonFormField<String>);
      expect(selectors, findsNWidgets(2));
      for (final selector in selectors.evaluate()) {
        expect(
          tester.getSize(find.byWidget(selector.widget)).height,
          AppSizes.buttonHeight,
        );
      }

      final translation = find.widgetWithText(SelectableText, 'сила');
      final translationWidget = tester.widget<SelectableText>(translation);
      expect(
        translationWidget.style,
        Theme.of(tester.element(translation)).textTheme.headlineSmall,
      );
      semantics.dispose();
    },
  );

  testWidgets('text translation hides lexical-only result fields', (
    tester,
  ) async {
    final preferences = await PreferencesService.create(
      supportedCodes: const ['en', 'ru'],
    );
    await preferences.update(
      (prefs) => prefs.copyWith(translationTargetLanguageCode: 'ru'),
    );

    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: ReadflexSupportedLocales.locales,
        localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
        theme: AppTheme.light(),
        home: Scaffold(
          body: TranslateSheet(
            selection: _paragraphSelection,
            translationService: _FakeTranslationService(
              includeLexicalDetails: true,
            ),
            preferencesService: preferences,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Запуски в наши дни в основном произвольны.'), findsOne);
    expect(find.text('launch'), findsNothing);
    expect(find.text('Sentence'), findsNothing);
    expect(find.text('Lexical explanation'), findsNothing);
    expect(find.text('релизы'), findsNothing);

    final translation = find.widgetWithText(
      SelectableText,
      'Запуски в наши дни в основном произвольны.',
    );
    final translationWidget = tester.widget<SelectableText>(translation);
    expect(
      translationWidget.style,
      Theme.of(tester.element(translation)).textTheme.bodyLarge,
    );
  });

  testWidgets('short multi-word translation uses readable body typography', (
    tester,
  ) async {
    final preferences = await PreferencesService.create(
      supportedCodes: const ['en', 'ru'],
    );
    await preferences.update(
      (prefs) => prefs.copyWith(translationTargetLanguageCode: 'ru'),
    );

    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: ReadflexSupportedLocales.locales,
        localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
        theme: AppTheme.light(),
        home: Scaffold(
          body: TranslateSheet(
            selection: _phraseSelection,
            translationService: const _FakeTranslationService(),
            preferencesService: preferences,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final translation = find.widgetWithText(SelectableText, 'сила');
    final translationWidget = tester.widget<SelectableText>(translation);
    expect(
      translationWidget.style,
      Theme.of(tester.element(translation)).textTheme.bodyLarge,
    );
  });
}

const _selection = TextSelectionContext(
  selectedText: 'power',
  normalizedSelectedText: 'power',
  sourceId: 'source-1',
  sourceType: SourceType.article,
  sourceLanguageHint: 'en',
);

const _paragraphSelection = TextSelectionContext(
  selectedText: 'Launches are mostly arbitrary these days.',
  sourceId: 'source-1',
  sourceType: SourceType.article,
  sourceLanguageHint: 'en',
);

const _phraseSelection = TextSelectionContext(
  selectedText: 'power bank',
  sourceId: 'source-1',
  sourceType: SourceType.article,
  sourceLanguageHint: 'en',
);

class _FakeTranslationService implements ContextualTranslationService {
  const _FakeTranslationService({this.includeLexicalDetails = false});

  final bool includeLexicalDetails;

  @override
  Future<ContextualTranslationResult> translate(
    ContextualTranslationRequest request, {
    bool allowOfflineModelDownload = false,
  }) async {
    return ContextualTranslationResult(
      requestId: request.requestId,
      mode: request.mode,
      status: ContextualTranslationStatus.resolved,
      reliability: ContextualTranslationReliability.verified,
      detectedSourceLanguage: 'en',
      targetLanguage: request.targetLanguage,
      analysis: includeLexicalDetails
          ? const ContextualTranslationAnalysis(lemma: 'launch')
          : null,
      translation: ContextualTranslationText(
        contextualTranslation: includeLexicalDetails
            ? 'Запуски в наши дни в основном произвольны.'
            : 'сила',
        sentenceTranslation: includeLexicalDetails
            ? 'Лексический перевод предложения.'
            : null,
      ),
      explanation: includeLexicalDetails ? 'Lexical explanation' : null,
      alternatives: includeLexicalDetails
          ? const [ContextualTranslationAlternative(translation: 'релизы')]
          : const [],
    );
  }

  @override
  void dispose() {}
}
