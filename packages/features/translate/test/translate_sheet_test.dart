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
    'renders contextual source preview and compact language selectors',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpTranslateSheet(tester, selection: _selection);

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

      final preview = _previewText(tester);
      expect(
        preview.textSpan?.toPlainText(),
        'This power bank provides emergency power.',
      );
      final selectedSpan = _previewSpans(
        tester,
      ).singleWhere((span) => span.text == 'power');
      expect(selectedSpan.style?.fontWeight, FontWeight.w600);
      expect(
        selectedSpan.style?.backgroundColor,
        Theme.of(tester.element(_previewFinder)).colorScheme.primaryContainer,
      );

      final translation = find.byKey(
        const ValueKey('translation-primary-result'),
      );
      final translationWidget = tester.widget<SelectableText>(translation);
      expect(translationWidget.data, 'сила');
      expect(
        translationWidget.style,
        Theme.of(tester.element(translation)).textTheme.headlineSmall,
      );
      semantics.dispose();
    },
  );

  testWidgets(
    'lexical lookup shows the full sentence translation before details',
    (tester) async {
      await _pumpTranslateSheet(
        tester,
        selection: _selection,
        service: const _FakeTranslationService(includeLexicalDetails: true),
      );

      expect(find.text('питание'), findsOneWidget);
      expect(find.text('Sentence'), findsOneWidget);
      expect(
        find.text('Этот аккумулятор обеспечивает аварийное питание.'),
        findsOneWidget,
      );
      expect(find.text('power'), findsOneWidget);
      expect(find.text('Lexical explanation'), findsOneWidget);
      expect(find.text('релизы'), findsOneWidget);

      final primary = find.byKey(const ValueKey('translation-primary-result'));
      final sentence = find.byKey(
        const ValueKey('translation-sentence-result'),
      );
      expect(
        tester.getTopLeft(primary).dy,
        lessThan(tester.getTopLeft(sentence).dy),
      );
      expect(
        tester.getTopLeft(sentence).dy,
        lessThan(tester.getTopLeft(find.text('Lexical explanation')).dy),
      );
    },
  );

  testWidgets('text translation uses exact source and hides lexical fields', (
    tester,
  ) async {
    await _pumpTranslateSheet(
      tester,
      selection: _paragraphSelection,
      service: const _FakeTranslationService(includeLexicalDetails: true),
    );

    expect(
      _previewText(tester).textSpan?.toPlainText(),
      _paragraphSelection.selectedText,
    );
    expect(find.text('Запуски в наши дни в основном произвольны.'), findsOne);
    expect(find.text('power'), findsNothing);
    expect(find.text('Sentence'), findsNothing);
    expect(find.text('Lexical explanation'), findsNothing);
    expect(find.text('релизы'), findsNothing);

    final translation = find.byKey(
      const ValueKey('translation-primary-result'),
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
    await _pumpTranslateSheet(tester, selection: _phraseSelection);

    final translation = find.byKey(
      const ValueKey('translation-primary-result'),
    );
    final translationWidget = tester.widget<SelectableText>(translation);
    expect(
      translationWidget.style,
      Theme.of(tester.element(translation)).textTheme.bodyLarge,
    );
  });

  testWidgets('malformed marked context falls back to clean context text', (
    tester,
  ) async {
    await _pumpTranslateSheet(tester, selection: _malformedMarkedSelection);

    final preview = _previewText(tester);
    expect(
      preview.textSpan?.toPlainText(),
      'A portable battery stores power safely.',
    );
    expect(preview.textSpan?.toPlainText(), isNot(contains('[[')));
    expect(
      _previewSpans(tester).singleWhere((span) => span.text == 'power'),
      isNotNull,
    );
  });

  testWidgets('stale marked context is rejected for the current selection', (
    tester,
  ) async {
    await _pumpTranslateSheet(tester, selection: _staleMarkedSelection);

    expect(
      _previewText(tester).textSpan?.toPlainText(),
      'This power bank is compact.',
    );
    expect(
      _previewSpans(tester).singleWhere((span) => span.text == 'power bank'),
      isNotNull,
    );
  });

  testWidgets('long lexical result is constrained and scrollable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpTranslateSheet(
      tester,
      selection: _selection,
      service: const _FakeTranslationService(
        includeLexicalDetails: true,
        alternativeCount: 16,
      ),
    );

    final scrollView = find.byType(SingleChildScrollView);
    expect(scrollView, findsOneWidget);
    expect(tester.getSize(scrollView).height, closeTo(408, 0.001));
    expect(find.text('вариант 16'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpTranslateSheet(
  WidgetTester tester, {
  required TextSelectionContext selection,
  ContextualTranslationService service = const _FakeTranslationService(),
}) async {
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
          selection: selection,
          translationService: service,
          preferencesService: preferences,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder get _previewFinder =>
    find.byKey(const ValueKey('translation-selection-preview-text'));

Text _previewText(WidgetTester tester) => tester.widget<Text>(_previewFinder);

List<TextSpan> _previewSpans(WidgetTester tester) {
  final root = _previewText(tester).textSpan! as TextSpan;
  return root.children!.whereType<TextSpan>().toList(growable: false);
}

const _selection = TextSelectionContext(
  selectedText: 'power',
  normalizedSelectedText: 'power',
  contextText: 'This power bank provides emergency power.',
  markedContextText: 'This [[power]] bank provides emergency power.',
  normalizedMarkedContextText: 'This [[power]] bank provides emergency power.',
  sourceId: 'source-1',
  sourceType: SourceType.article,
  sourceLanguageHint: 'en',
);

const _paragraphSelection = TextSelectionContext(
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

const _phraseSelection = TextSelectionContext(
  selectedText: 'power bank',
  sourceId: 'source-1',
  sourceType: SourceType.article,
  sourceLanguageHint: 'en',
);

const _malformedMarkedSelection = TextSelectionContext(
  selectedText: 'power',
  contextText: 'A portable battery stores power safely.',
  markedContextText: 'A portable battery stores [[power safely.',
  sourceId: 'source-1',
  sourceType: SourceType.article,
  sourceLanguageHint: 'en',
);

const _staleMarkedSelection = TextSelectionContext(
  selectedText: 'power bank',
  contextText: 'This power bank is compact.',
  markedContextText: 'This [[power]] bank is compact.',
  sourceId: 'source-1',
  sourceType: SourceType.article,
  sourceLanguageHint: 'en',
);

class _FakeTranslationService implements ContextualTranslationService {
  const _FakeTranslationService({
    this.includeLexicalDetails = false,
    this.alternativeCount = 1,
  });

  final bool includeLexicalDetails;
  final int alternativeCount;

  @override
  Future<ContextualTranslationResult> translate(
    ContextualTranslationRequest request, {
    bool allowOfflineModelDownload = false,
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
        contextualTranslation: isTextTranslation
            ? 'Запуски в наши дни в основном произвольны.'
            : includeLexicalDetails
            ? 'питание'
            : 'сила',
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
