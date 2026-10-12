import 'package:component_library/component_library.dart';
import 'package:contextual_translation_service/contextual_translation_service.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:shared/shared.dart';
import 'package:translate/translate.dart';

// Shared by the translation sheet tests: pumping the sheet, fake services,
// selections and finders.

Future<void> pumpTranslateSheet(
  WidgetTester tester, {
  required TextSelectionContext selection,
  ContextualTranslationService service = const FakeTranslationService(),
  TextScaler textScaler = TextScaler.noScaling,
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
}) async {
  final preferences = await PreferencesService.create(
    supportedCodes: ReadflexSupportedLocales.codes,
  );
  addTearDown(preferences.dispose);
  await preferences.update(
    (prefs) => prefs.copyWith(translationTargetLanguageCode: 'ru'),
  );

  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: ReadflexSupportedLocales.locales,
      localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
      theme: brightness == Brightness.light
          ? AppTheme.light()
          : AppTheme.dark(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: Scaffold(
        body: TranslateSheet(
          selection: selection,
          translationService: service,
          preferencesService: preferences,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder get previewFinder =>
    find.byKey(const ValueKey('translation-selection-preview-text'));

Finder get selectedFragmentFinder =>
    find.byKey(const ValueKey('translation-selected-fragment'));

Finder get quoteSurfaceFinder => find.byWidgetPredicate(
  (widget) =>
      widget is Container &&
      widget.decoration is BoxDecoration &&
      (widget.decoration! as BoxDecoration).border is BorderDirectional,
);

/// The selection, word or phrase, is a quiet `titleMedium` label, not a
/// quote.
void expectSubject(WidgetTester tester) {
  expect(
    find.ancestor(of: selectedFragmentFinder, matching: quoteSurfaceFinder),
    findsNothing,
  );
  final fragment = tester.widget<SelectableText>(selectedFragmentFinder);
  final theme = Theme.of(tester.element(selectedFragmentFinder));
  expect(fragment.style!.fontSize, theme.textTheme.titleMedium!.fontSize);
  expect(fragment.style!.fontFamily, isNot(AppTypography.fontFamilySerif));
}

const powerSelection = TextSelectionContext(
  selectedText: 'power',
  normalizedSelectedText: 'power',
  contextText: 'This power bank provides emergency power.',
  markedContextText: 'This [[power]] bank provides emergency power.',
  normalizedMarkedContextText: 'This [[power]] bank provides emergency power.',
  sourceId: 'source-1',
  sourceType: SourceType.article,
  sourceLanguageHint: 'en',
);

const paragraphSelection = TextSelectionContext(
  selectedText: 'Launches are mostly arbitrary these days.',
  contextText:
      'Before this point. Launches are mostly arbitrary these days. After it.',
  markedContextText:
      'Before this point. [[Launches are mostly arbitrary these days.]] '
      'After it.',
  sourceId: 'source-1',
  sourceType: SourceType.article,
  sourceLanguageHint: 'en',
);

class WordTranslationService implements ContextualTranslationService {
  WordTranslationService(
    this.translation, {
    this.analysis,
    this.expression,
    this.explanation,
  });

  final ContextualTranslationText translation;
  final ContextualTranslationAnalysis? analysis;
  final String? explanation;
  final ContextualTranslationExpression? expression;
  int calls = 0;

  @override
  Future<ContextualTranslationResult> translate(
    ContextualTranslationRequest request, {
    bool allowOfflineModelDownload = false,
    Future<void>? abortTrigger,
  }) async {
    calls++;
    return ContextualTranslationResult(
      requestId: request.requestId,
      mode: request.mode,
      status: ContextualTranslationStatus.resolved,
      reliability: ContextualTranslationReliability.verified,
      translation: translation,
      analysis: analysis,
      contextualExpression: expression,
      explanation: explanation,
    );
  }

  @override
  void dispose() {}
}

class FakeTranslationService implements ContextualTranslationService {
  const FakeTranslationService({
    this.includeLexicalDetails = false,
    this.alternativeCount = 1,
    this.primary,
  });

  final bool includeLexicalDetails;
  final int alternativeCount;
  final String? primary;

  @override
  Future<ContextualTranslationResult> translate(
    ContextualTranslationRequest request, {
    bool allowOfflineModelDownload = false,
    Future<void>? abortTrigger,
  }) async {
    final isTextTranslation = request.mode == selectedTextTranslationMode;
    return ContextualTranslationResult(
      requestId: request.requestId,
      mode: request.mode,
      status: ContextualTranslationStatus.resolved,
      reliability: ContextualTranslationReliability.verified,
      detectedSourceLanguage: 'en',
      targetLanguage: request.targetLanguage,
      analysis: includeLexicalDetails
          ? const ContextualTranslationAnalysis(lemma: 'power')
          : null,
      translation: ContextualTranslationText(
        contextualTranslation:
            primary ??
            (isTextTranslation
                ? 'Запуски в наши дни в основном произвольны.'
                : includeLexicalDetails
                ? 'питание'
                : 'сила'),
        sentenceTranslation: includeLexicalDetails
            ? 'Этот аккумулятор обеспечивает аварийное питание.'
            : null,
      ),
      explanation: includeLexicalDetails ? 'Lexical explanation' : null,
      alternatives: includeLexicalDetails
          ? List.generate(
              alternativeCount,
              (index) => ContextualTranslationAlternative(
                translation: index == 0 ? 'релизы' : 'вариант ${index + 1}',
              ),
            )
          : const [],
    );
  }

  @override
  void dispose() {}
}

/// The outline of [section]: its full height, [AppSheetSection.outlineInset]
/// in from either side.
Rect sectionOutline(WidgetTester tester, Finder section) {
  final rect = tester.getRect(section);
  return Rect.fromLTRB(
    rect.left + AppSheetSection.outlineInset,
    rect.top,
    rect.right - AppSheetSection.outlineInset,
    rect.bottom,
  );
}
