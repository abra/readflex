import 'package:component_library/component_library.dart';
import 'package:dictionary/dictionary.dart';
import 'package:dictionary_service/dictionary_service.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:shared/shared.dart';

void main() {
  testWidgets('long dictionary result is constrained and scrollable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: ReadflexSupportedLocales.locales,
        localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
        theme: AppTheme.light(),
        home: const Scaffold(
          body: DictionarySheet(
            selection: _selection,
            dictionaryService: _LongDictionaryService(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollView = find.byType(SingleChildScrollView);
    expect(scrollView, findsOneWidget);
    expect(tester.getSize(scrollView).height, closeTo(408, 0.001));
    expect(find.text('Definition 20'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

const _selection = TextSelectionContext(
  selectedText: 'power',
  sourceId: 'article-1',
  sourceType: SourceType.article,
  sourceLanguageHint: 'en',
);

class _LongDictionaryService implements DictionaryLookupService {
  const _LongDictionaryService();

  @override
  Future<DictionaryLookupResult> lookup(DictionaryLookupRequest request) async {
    return DictionaryLookupResult(
      requestId: request.requestId,
      status: DictionaryLookupStatus.found,
      term: request.term,
      language: 'en',
      entries: [
        DictionaryLexicalEntry(
          lemma: 'power',
          partOfSpeech: 'noun',
          definitions: List.generate(
            20,
            (index) => DictionaryDefinition(
              text: 'Definition ${index + 1}',
              examples: ['Example ${index + 1}'],
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {}
}
