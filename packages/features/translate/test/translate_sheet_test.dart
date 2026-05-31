import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';
import 'package:translate/translate.dart';
import 'package:translation_service/translation_service.dart';

import 'helpers/fake_dictionary_repository.dart';
import 'helpers/fake_fsrs_repository.dart';
import 'helpers/fake_translation_service.dart';

const _selection = TextSelectionContext(
  selectedText: 'serendipity',
  sourceId: 'book-1',
  sourceType: SourceType.book,
);

void main() {
  late FakeTranslationService translationService;
  late FakeDictionaryRepository dictionaryRepository;
  late FakeFsrsRepository fsrsRepository;

  setUp(() {
    translationService = FakeTranslationService();
    dictionaryRepository = FakeDictionaryRepository();
    fsrsRepository = FakeFsrsRepository();
  });

  Widget buildSubject({TextSelectionContext selection = _selection}) =>
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: TranslateSheet(
              translationService: translationService,
              dictionaryRepository: dictionaryRepository,
              fsrsRepository: fsrsRepository,
              selection: selection,
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

  testWidgets('translates normalized text while previewing exact selection', (
    tester,
  ) async {
    const selection = TextSelectionContext(
      selectedText: 'cumven',
      normalizedSelectedText: 'circumvent',
      selectionKind: 'partial_word',
      sourceId: 'book-1',
      sourceType: SourceType.book,
      contextText: 'The team will circumvent the restriction.',
      markedContextText: 'The team will cir[[cumven]]t the restriction.',
      normalizedMarkedContextText:
          'The team will [[circumvent]] the restriction.',
    );

    await tester.pumpWidget(buildSubject(selection: selection));
    await tester.pump();

    expect(find.text('cumven'), findsOneWidget);
    expect(find.text('[ru] circumvent'), findsOneWidget);
    expect(translationService.lastText, 'circumvent');
    expect(
      translationService.lastContextText,
      'The team will [[circumvent]] the restriction.',
    );
  });

  testWidgets('shows Save to Dictionary button after translation', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('Save to Dictionary'), findsOneWidget);
  });

  testWidgets('saves normalized text to dictionary for partial selections', (
    tester,
  ) async {
    const selection = TextSelectionContext(
      selectedText: 'cumven',
      normalizedSelectedText: 'circumvent',
      selectionKind: 'partial_word',
      sourceId: 'book-1',
      sourceType: SourceType.book,
    );

    await tester.pumpWidget(buildSubject(selection: selection));
    await tester.pump();
    await tester.tap(find.text('Save to Dictionary'));
    await tester.pump();

    expect(dictionaryRepository.entries, hasLength(1));
    expect(dictionaryRepository.entries.single.word, 'circumvent');
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

  testWidgets('renders marked source-language usage examples', (tester) async {
    translationService.resultOverride = const TranslationResult(
      originalText: 'up',
      translatedText: 'искать',
      source: TranslationSource.remote,
      usageExamples: ['She [[looked up]] the word.'],
    );

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    final exampleFinder = find.byWidgetPredicate(
      (widget) =>
          widget is RichText &&
          widget.text.toPlainText() == 'She looked up the word.',
    );
    expect(exampleFinder, findsOneWidget);
    expect(find.text('She [[looked up]] the word.'), findsNothing);

    final richText = tester.widget<RichText>(exampleFinder);
    final rootSpan = richText.text as TextSpan;
    TextSpan? markedSpan;
    rootSpan.visitChildren((span) {
      if (span is TextSpan && span.text == 'looked up') {
        markedSpan = span;
      }
      return true;
    });
    expect(markedSpan?.style?.fontWeight, FontWeight.w700);
  });

  testWidgets('shows contextual explanation when present', (tester) async {
    translationService.resultOverride = const TranslationResult(
      originalText: 'up',
      translatedText: 'искать',
      source: TranslationSource.remote,
      context: 'Часть фразового глагола "look up": искать информацию.',
    );

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('искать'), findsOneWidget);
    expect(
      find.text('Часть фразового глагола "look up": искать информацию.'),
      findsOneWidget,
    );
  });

  testWidgets('shows singular lemma and transcription for plural words', (
    tester,
  ) async {
    translationService.resultOverride = const TranslationResult(
      originalText: 'stakeholders',
      translatedText: 'заинтересованные стороны',
      source: TranslationSource.remote,
      sense: TranslationSense(
        partOfSpeech: 'noun',
        lemma: 'stakeholder',
        lemmaTranscription: '/ˈsteɪkˌhoʊldər/',
        grammaticalForm: 'plural',
        sourceDefinition: 'People or groups with an interest in something.',
      ),
    );

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    bool richTextContains(String text) => tester
        .widgetList<RichText>(find.byType(RichText))
        .any((widget) => widget.text.toPlainText().contains(text));

    expect(richTextContains('Part of speech: noun'), isTrue);
    expect(
      richTextContains('Singular: stakeholder /ˈsteɪkˌhoʊldər/'),
      isTrue,
    );
  });

  testWidgets('shows structured translation details when present', (
    tester,
  ) async {
    translationService.resultOverride = const TranslationResult(
      originalText: 'things',
      translatedText: 'начать',
      source: TranslationSource.remote,
      answerType: TranslationAnswerType.expressionExplanation,
      confidence: TranslationConfidence.low,
      sense: TranslationSense(
        partOfSpeech: 'noun',
        transcription: '/θɪŋz/',
        sourceDefinition: 'To start an activity or process.',
        targetDefinition: 'Начать действие или процесс.',
        sourceContextNote: 'Kick is used as part of kick off.',
        targetContextNote: 'В этом контексте подходит «начать».',
      ),
      expression: TranslationExpression(
        term: 'things',
        surface: 'kick things off',
        lexicalUnit: 'kick off',
        expressionType: 'separable_phrasal_verb',
        selectedRole: 'verb',
        canonicalPattern: 'kick [object] off',
      ),
      naturalEquivalents: ['запустить'],
      literalTranslation: 'пнуть вещи прочь',
      suggestedFullPhrase: TranslationTextPair(
        source: 'kick things off',
        target: 'начать дело',
      ),
      notes: TranslationTextPair(target: 'Things is an inserted object.'),
    );

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    bool richTextContains(String text) => tester
        .widgetList<RichText>(find.byType(RichText))
        .any((widget) => widget.text.toPlainText().contains(text));

    expect(find.text('начать'), findsOneWidget);
    final detailsText = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((widget) => widget.text.toPlainText())
        .join('\n');

    expect(find.text('Low confidence'), findsOneWidget);
    expect(richTextContains('Part of speech: noun'), isTrue);
    expect(richTextContains('Transcription: /θɪŋz/'), isTrue);
    expect(
      detailsText.indexOf('Literal:'),
      lessThan(detailsText.indexOf('In context:')),
    );
    expect(
      detailsText.indexOf('In context:'),
      lessThan(detailsText.indexOf('Source:')),
    );
    expect(richTextContains('To start an activity or process.'), isTrue);
    expect(richTextContains('Начать действие или процесс.'), isTrue);
    expect(richTextContains('Kick is used as part of kick off.'), isTrue);
    expect(richTextContains('В этом контексте подходит «начать».'), isTrue);
    expect(
      richTextContains(
        '"things" is used in the phrasal verb "kick off" here as "kick things off".',
      ),
      isTrue,
    );
    expect(
      richTextContains('"things" is part of the phrasal verb'),
      isFalse,
    );
    expect(richTextContains('kick things off'), isTrue);
    expect(richTextContains('lexical unit: kick off'), isFalse);
    expect(richTextContains('role: verb'), isFalse);
    expect(richTextContains('pattern: kick [object] off'), isFalse);
    expect(richTextContains('separable phrasal verb'), isFalse);
    expect(richTextContains('запустить'), isTrue);
    expect(richTextContains('пнуть вещи прочь'), isTrue);
    expect(richTextContains('начать дело'), isFalse);
    expect(richTextContains('Things is an inserted object.'), isTrue);
  });

  testWidgets(
    'does not render expression and full phrase as separate debug rows',
    (tester) async {
      translationService.resultOverride = const TranslationResult(
        originalText: 'out',
        translatedText: 'вне',
        source: TranslationSource.remote,
        answerType: TranslationAnswerType.expressionExplanation,
        expression: TranslationExpression(
          term: 'out',
          surface: 'out of service',
          lexicalUnit: 'out of service',
          expressionType: 'fixed_expression',
          selectedRole: 'component',
        ),
        suggestedFullPhrase: TranslationTextPair(
          source: 'out of service',
          target: 'не работает',
        ),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pump();

      final detailsText = tester
          .widgetList<RichText>(find.byType(RichText))
          .map((widget) => widget.text.toPlainText())
          .join('\n');

      expect(detailsText, contains('In context:'));
      expect(detailsText, isNot(contains('Expression:')));
      expect(detailsText, isNot(contains('Full phrase:')));
      expect(detailsText, isNot(contains('role: component')));
    },
  );

  testWidgets('keeps selected text translation before expression details', (
    tester,
  ) async {
    translationService.resultOverride = const TranslationResult(
      originalText: 'In',
      translatedText: 'в',
      source: TranslationSource.remote,
      answerType: TranslationAnswerType.expressionExplanation,
      sense: TranslationSense(
        sourceDefinition: 'A preposition that can indicate location or state.',
        targetDefinition:
            'Предлог, который может обозначать место или состояние.',
        sourceContextNote:
            'Here it begins the fixed expression in other words.',
        targetContextNote: 'Вся фраза переводится как «другими словами».',
      ),
      expression: TranslationExpression(
        term: 'In',
        surface: 'in other words',
        lexicalUnit: 'in other words',
        expressionType: 'fixed_expression',
        selectedRole: 'first word',
      ),
      naturalEquivalents: ['иначе говоря'],
      literalTranslation: 'в',
      suggestedFullPhrase: TranslationTextPair(
        source: 'in other words',
        target: 'другими словами',
      ),
    );

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    bool richTextContains(String text) => tester
        .widgetList<RichText>(find.byType(RichText))
        .any((widget) => widget.text.toPlainText().contains(text));

    final detailsText = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((widget) => widget.text.toPlainText())
        .join('\n');

    expect(find.text('в'), findsOneWidget);
    expect(
      richTextContains(
        '"In" is part of the fixed expression "in other words" in this sentence.',
      ),
      isTrue,
    );
    expect(detailsText, isNot(contains('Expression:')));
    expect(detailsText, isNot(contains('Full phrase:')));
    expect(richTextContains('in other words'), isTrue);
    expect(richTextContains('другими словами'), isTrue);
    expect(richTextContains('Related'), isTrue);
    expect(richTextContains('иначе говоря'), isTrue);
    expect(richTextContains('Literal:'), isFalse);
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
