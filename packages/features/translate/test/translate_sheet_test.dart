import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';
import 'package:translate/translate.dart';
import 'package:translation_service/translation_service.dart';

import 'helpers/fake_dictionary_repository.dart';
import 'helpers/fake_translation_service.dart';

const _selection = TextSelectionContext(
  selectedText: 'serendipity',
  sourceId: 'book-1',
  sourceType: SourceType.book,
);

void main() {
  late FakeTranslationService translationService;
  late FakeDictionaryRepository dictionaryRepository;

  setUp(() {
    translationService = FakeTranslationService();
    dictionaryRepository = FakeDictionaryRepository();
  });

  Widget buildSubject() => MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: SingleChildScrollView(
        child: TranslateSheet(
          translationService: translationService,
          dictionaryRepository: dictionaryRepository,
          selection: _selection,
        ),
      ),
    ),
  );

  testWidgets('renders title and selected text', (tester) async {
    await tester.pumpWidget(buildSubject());

    expect(find.text('Translate'), findsOneWidget);
    expect(find.text('serendipity'), findsOneWidget);
  });

  testWidgets('shows translation result after auto-translate', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump(); // let async translate complete

    expect(find.text('[ru] serendipity'), findsOneWidget);
  });

  testWidgets('shows Save to Dictionary button after translation', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('Save to Dictionary'), findsOneWidget);
  });

  testWidgets('shows usage examples when present', (tester) async {
    translationService.resultOverride = const TranslationResult(
      originalText: 'serendipity',
      translatedText: 'счастливая случайность',
      source: TranslationSource.remote,
      usageExamples: ['A serendipity led to the discovery.'],
    );

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('счастливая случайность'), findsOneWidget);
    expect(
      find.text('A serendipity led to the discovery.'),
      findsOneWidget,
    );
  });

  testWidgets('shows error message on translation failure', (tester) async {
    translationService.shouldThrow = true;

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('Translation failed'), findsOneWidget);
  });

  testWidgets('shows Save to Dictionary button on failure too', (
    tester,
  ) async {
    translationService.shouldThrow = true;

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('Save to Dictionary'), findsOneWidget);
  });

  testWidgets('save to dictionary adds entry', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    await tester.tap(find.text('Save to Dictionary'));
    await tester.pump();

    expect(dictionaryRepository.entries, hasLength(1));
    expect(dictionaryRepository.entries.first.word, 'serendipity');
  });
}
