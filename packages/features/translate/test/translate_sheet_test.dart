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

  Widget buildSubject({
    TextSelectionContext selection = _selection,
    String? sourceLanguageCode,
    String targetLanguageCode = 'ru',
    double? height,
  }) => MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: SizedBox(
        height: height,
        child: TranslateSheet(
          translationService: translationService,
          dictionaryRepository: dictionaryRepository,
          fsrsRepository: fsrsRepository,
          selection: selection,
          sourceLanguageCode: sourceLanguageCode,
          targetLanguageCode: targetLanguageCode,
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

    expect(find.text('[ru] serendipity'), findsWidgets);
  });

  testWidgets('uses configured translation languages', (tester) async {
    await tester.pumpWidget(
      buildSubject(
        sourceLanguageCode: 'ru',
        targetLanguageCode: 'en',
      ),
    );
    await tester.pump();

    expect(translationService.lastFromLang, 'ru');
    expect(translationService.lastToLang, 'en');
    expect(find.text('[en] serendipity'), findsWidgets);
  });

  testWidgets('auto-detects Cyrillic source language', (tester) async {
    const selection = TextSelectionContext(
      selectedText: 'привет',
      sourceId: 'book-1',
      sourceType: SourceType.book,
    );

    await tester.pumpWidget(
      buildSubject(
        selection: selection,
        targetLanguageCode: 'en',
      ),
    );
    await tester.pump();

    expect(translationService.lastFromLang, 'ru');
    expect(translationService.lastToLang, 'en');
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
    expect(find.text('[ru] circumvent'), findsWidgets);
    expect(translationService.lastText, 'circumvent');
    expect(
      translationService.lastContextText,
      'The team will [[circumvent]] the restriction.',
    );
  });

  testWidgets('shows dictionary save action after translation', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.widgetWithText(TextButton, 'Save'), findsOneWidget);
  });

  testWidgets('aligns save action baseline with selected term', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    double textBaseline(Finder finder) {
      final element = tester.element(finder);
      final widget = tester.widget<Text>(finder);
      final inheritedStyle = DefaultTextStyle.of(element).style;
      final style = inheritedStyle.merge(widget.style);
      final painter = TextPainter(
        text: TextSpan(text: widget.data, style: style),
        textDirection: Directionality.of(element),
      )..layout();
      final baseline = painter.computeDistanceToActualBaseline(
        TextBaseline.alphabetic,
      );
      return tester.getTopLeft(finder).dy + baseline;
    }

    final wordBaseline = textBaseline(find.text('serendipity'));
    final saveBaseline = textBaseline(find.text('Save'));

    expect((wordBaseline - saveBaseline).abs(), lessThanOrEqualTo(6));
  });

  testWidgets('keeps save action size stable after saving', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    final saveFinder = find.widgetWithText(TextButton, 'Save');
    final beforeSize = tester.getSize(saveFinder);

    await tester.tap(saveFinder);
    await tester.pumpAndSettle();

    final undoFinder = find.widgetWithText(TextButton, 'Undo');
    expect(undoFinder, findsOneWidget);
    expect(tester.getSize(undoFinder), beforeSize);
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
      cfiRange: 'epubcfi(/6/4!/4/2,/1:3,/1:9)',
      normalizedCfiRange: 'epubcfi(/6/4!/4/2,/1:0,/1:12)',
    );

    await tester.pumpWidget(buildSubject(selection: selection));
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pump();

    expect(dictionaryRepository.entries, hasLength(1));
    expect(dictionaryRepository.entries.single.word, 'circumvent');
    expect(dictionaryRepository.anchors, hasLength(1));
    expect(
      dictionaryRepository.anchors.single.cfiRange,
      'epubcfi(/6/4!/4/2,/1:0,/1:12)',
    );
    expect(
      dictionaryRepository.anchors.single.kind,
      DictionaryAnchorKind.normalizedSelection,
    );
  });

  testWidgets('offers separate save actions for selected word and expression', (
    tester,
  ) async {
    const selection = TextSelectionContext(
      selectedText: 'kick',
      sourceId: 'book-1',
      sourceType: SourceType.book,
      contextText: 'It is time to kick things off.',
    );
    translationService.resultOverride = const TranslationResult(
      originalText: 'kick',
      translatedText: 'пинать',
      source: TranslationSource.remote,
      answerType: TranslationAnswerType.expressionExplanation,
      sense: TranslationSense(
        partOfSpeech: 'verb',
        transcription: '/kɪk/',
        targetDefinition: 'Начать действие или процесс.',
      ),
      expression: TranslationExpression(
        term: 'kick',
        surface: 'kick things off',
        lexicalUnit: 'kick off',
        expressionType: 'phrasal_verb',
      ),
      suggestedFullPhrase: TranslationTextPair(
        source: 'kick things off',
        target: 'начать дело',
      ),
      usageExamples: ['It is time to [[kick things off]].'],
    );

    await tester.pumpWidget(buildSubject(selection: selection));
    await tester.pump();

    final detailsText = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((widget) => widget.text.toPlainText())
        .join('\n');

    expect(find.text('kick off'), findsOneWidget);
    expect(detailsText, contains('Target: начать дело'));
    expect(find.widgetWithText(TextButton, 'Save'), findsNWidgets(2));

    await tester.tap(find.widgetWithText(TextButton, 'Save').first);
    await tester.pump();

    expect(dictionaryRepository.entries, hasLength(1));
    expect(dictionaryRepository.entries[0].word, 'kick');
    expect(dictionaryRepository.entries[0].translation, 'пинать');
    expect(
      dictionaryRepository.entries[0].context,
      'It is time to [[kick]] things off.',
    );
    expect(find.widgetWithText(TextButton, 'Undo'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Save').last);
    await tester.pump();

    expect(dictionaryRepository.entries, hasLength(2));
    expect(dictionaryRepository.entries[1].word, 'kick off');
    expect(dictionaryRepository.entries[1].translation, 'начать дело');
    expect(dictionaryRepository.entries[1].partOfSpeech, 'phrasal verb');
    expect(
      dictionaryRepository.entries[1].context,
      'It is time to [[kick things off]].',
    );
    expect(
      dictionaryRepository.entries[1].usageExamples,
      ['It is time to [[kick things off]].'],
    );
    expect(find.widgetWithText(TextButton, 'Undo'), findsNWidgets(2));
  });

  testWidgets('labels broader MWE categories from translation results', (
    tester,
  ) async {
    const selection = TextSelectionContext(
      selectedText: 'look',
      sourceId: 'book-1',
      sourceType: SourceType.book,
      contextText: 'Take a look at the report.',
    );
    translationService.resultOverride = const TranslationResult(
      originalText: 'look',
      translatedText: 'взгляд',
      source: TranslationSource.remote,
      answerType: TranslationAnswerType.expressionExplanation,
      expression: TranslationExpression(
        term: 'look',
        surface: 'take a look',
        lexicalUnit: 'take a look',
        expressionType: 'light_verb_construction',
      ),
      suggestedFullPhrase: TranslationTextPair(
        source: 'take a look',
        target: 'посмотреть',
      ),
    );

    await tester.pumpWidget(buildSubject(selection: selection));
    await tester.pump();

    expect(find.text('light verb construction'), findsOneWidget);
    expect(find.text('take a look'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Save').last);
    await tester.pump();

    expect(dictionaryRepository.entries, hasLength(1));
    expect(dictionaryRepository.entries.single.word, 'take a look');
    expect(dictionaryRepository.entries.single.translation, 'посмотреть');
    expect(
      dictionaryRepository.entries.single.partOfSpeech,
      'light verb construction',
    );
  });

  testWidgets('saves expression anchor from the selected token CFI', (
    tester,
  ) async {
    const selection = TextSelectionContext(
      selectedText: 'set',
      sourceId: 'book-1',
      sourceType: SourceType.book,
      contextText: 'We need to set up the project today.',
      markedContextText: 'We need to [[set]] up the project today.',
      cfiRange: 'epubcfi(/6/4!/4/2,/12:11,/12:14)',
    );
    translationService.resultOverride = const TranslationResult(
      originalText: 'set',
      translatedText: 'устанавливать',
      source: TranslationSource.remote,
      answerType: TranslationAnswerType.expressionExplanation,
      sense: TranslationSense(partOfSpeech: 'verb'),
      expression: TranslationExpression(
        term: 'set',
        surface: 'set up',
        lexicalUnit: 'set up',
        expressionType: 'phrasal_verb',
      ),
      suggestedFullPhrase: TranslationTextPair(
        source: 'set up',
        target: 'настроить',
      ),
      usageExamples: ['We need to [[set up]] the project today.'],
    );

    await tester.pumpWidget(buildSubject(selection: selection));
    await tester.pump();

    await tester.tap(find.widgetWithText(TextButton, 'Save').last);
    await tester.pump();

    expect(dictionaryRepository.entries, hasLength(1));
    expect(dictionaryRepository.entries.single.word, 'set up');
    expect(dictionaryRepository.anchors, hasLength(1));
    expect(dictionaryRepository.anchors.single.text, 'set up');
    expect(
      dictionaryRepository.anchors.single.cfiRange,
      'epubcfi(/6/4!/4/2,/12:11,/12:14)',
    );
    expect(
      dictionaryRepository.anchors.single.kind,
      DictionaryAnchorKind.expression,
    );
  });

  testWidgets('saves expression lexical unit separately from surface anchor', (
    tester,
  ) async {
    const selection = TextSelectionContext(
      selectedText: 'sends',
      sourceId: 'book-1',
      sourceType: SourceType.book,
      contextText: 'It sends us into a dizzying spin.',
      markedContextText: 'It [[sends]] us into a dizzying spin.',
      cfiRange: 'epubcfi(/6/4!/4/2,/4:3,/4:8)',
    );
    translationService.resultOverride = const TranslationResult(
      originalText: 'sends',
      translatedText: 'посылает',
      source: TranslationSource.remote,
      answerType: TranslationAnswerType.expressionExplanation,
      sense: TranslationSense(
        partOfSpeech: 'verb',
        sourceDefinition:
            'to cause someone or something to be in a particular state',
        targetDefinition:
            'приводить кого-либо или что-либо в определенное состояние',
      ),
      expression: TranslationExpression(
        term: 'sends',
        surface: 'sends us into a dizzying spin',
        lexicalUnit: 'send ... into',
        canonicalPattern: 'send someone/something into a state',
        expressionType: 'verb_pattern',
      ),
      expressionTranslation: TranslationTextPair(
        source: 'send ... into',
        target: 'приводить кого-либо в определенное состояние',
      ),
      suggestedFullPhrase: TranslationTextPair(
        source: 'sends us into a dizzying spin',
        target: 'ввергает нас в головокружительное состояние',
      ),
      usageExamples: ['It [[sends us into a dizzying spin]].'],
    );

    await tester.pumpWidget(buildSubject(selection: selection));
    await tester.pump();

    final detailsText = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((widget) => widget.text.toPlainText())
        .join('\n');
    expect(
      detailsText,
      isNot(contains('Source: send ... into')),
    );
    expect(
      detailsText,
      contains(
        'Source: to cause someone or something to be in a particular state',
      ),
    );
    expect(
      'Source: to cause someone or something to be in a particular state'
          .allMatches(detailsText)
          .length,
      1,
    );
    expect(
      detailsText,
      contains(
        'Target: приводить кого-либо или что-либо в определенное состояние',
      ),
    );

    await tester.tap(find.widgetWithText(TextButton, 'Save').last);
    await tester.pump();

    expect(dictionaryRepository.entries, hasLength(1));
    expect(dictionaryRepository.entries.single.word, 'send ... into');
    expect(
      dictionaryRepository.entries.single.translation,
      'приводить кого-либо в определенное состояние',
    );
    expect(
      dictionaryRepository.entries.single.context,
      'It [[sends us into a dizzying spin]].',
    );
    expect(dictionaryRepository.anchors, hasLength(1));
    expect(
      dictionaryRepository.anchors.single.text,
      'sends us into a dizzying spin',
    );
    expect(
      dictionaryRepository.anchors.single.cfiRange,
      'epubcfi(/6/4!/4/2,/4:3,/4:8)',
    );
    expect(
      dictionaryRepository.anchors.single.kind,
      DictionaryAnchorKind.expression,
    );
  });

  testWidgets('shows selected role as part of speech when sense omits it', (
    tester,
  ) async {
    const selection = TextSelectionContext(
      selectedText: 'sends',
      sourceId: 'book-1',
      sourceType: SourceType.book,
      contextText: 'It sends us into a dizzying spin.',
    );
    translationService.resultOverride = const TranslationResult(
      originalText: 'sends',
      translatedText: 'отправляет',
      source: TranslationSource.remote,
      answerType: TranslationAnswerType.expressionExplanation,
      expression: TranslationExpression(
        term: 'sends',
        surface: 'sends us into a dizzying spin',
        lexicalUnit: 'send ... into',
        expressionType: 'verb_pattern',
        selectedRole: 'verb',
      ),
      expressionTranslation: TranslationTextPair(
        source: 'send ... into',
        target: 'приводить кого-либо в состояние',
      ),
    );

    await tester.pumpWidget(buildSubject(selection: selection));
    await tester.pump();

    expect(find.text('verb'), findsOneWidget);
    expect(find.textContaining('infinitive'), findsNothing);
  });

  testWidgets('shows base form for inflected verbs from service lemma', (
    tester,
  ) async {
    const selection = TextSelectionContext(
      selectedText: 'sends',
      sourceId: 'book-1',
      sourceType: SourceType.book,
      contextText: 'It sends us into a dizzying spin.',
    );
    translationService.resultOverride = const TranslationResult(
      originalText: 'sends',
      translatedText: 'отправляет',
      source: TranslationSource.remote,
      sense: TranslationSense(
        lemma: 'send',
        lemmaTranscription: '/send/',
        grammaticalForm: 'third_person_singular',
      ),
    );

    await tester.pumpWidget(buildSubject(selection: selection));
    await tester.pump();

    final detailsText = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((widget) => widget.text.toPlainText())
        .join('\n');

    expect(find.textContaining('infinitive'), findsNothing);
    expect(detailsText, contains('Base form: send /send/'));
    expect(find.text('verb'), findsOneWidget);
    expect(find.text('/send/'), findsNothing);
  });

  testWidgets('does not save expression definitions as translations', (
    tester,
  ) async {
    const selection = TextSelectionContext(
      selectedText: 'burst',
      sourceId: 'book-1',
      sourceType: SourceType.book,
      contextText: 'Two cops burst in through the door at the back.',
    );
    translationService.resultOverride = const TranslationResult(
      originalText: 'burst',
      translatedText: 'вспыхнуть',
      source: TranslationSource.remote,
      answerType: TranslationAnswerType.expressionExplanation,
      sense: TranslationSense(
        targetDefinition: 'Внезапно и с силой войти в помещение.',
      ),
      expression: TranslationExpression(
        term: 'burst',
        surface: 'burst in',
        lexicalUnit: 'burst in',
        expressionType: 'phrasal_verb',
      ),
    );

    await tester.pumpWidget(buildSubject(selection: selection));
    await tester.pump();

    expect(find.text('Phrasal verb'), findsNothing);
    expect(find.widgetWithText(TextButton, 'Save'), findsOneWidget);
  });

  testWidgets('undo removes a saved dictionary option', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pump();

    expect(dictionaryRepository.entries, hasLength(1));
    expect(find.widgetWithText(TextButton, 'Undo'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Undo'));
    await tester.pump();

    expect(dictionaryRepository.entries, isEmpty);
    expect(find.widgetWithText(TextButton, 'Save'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Undo'), findsNothing);
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

    expect(find.text('счастливая случайность'), findsWidgets);
    expect(find.text('EXAMPLES'), findsOneWidget);
    expect(find.text('Example'), findsNothing);
    expect(find.text('In this text'), findsNothing);
    expect(
      find.text('A serendipity led to the discovery.'),
      findsOneWidget,
    );
  });

  testWidgets('labels original context separately from generated examples', (
    tester,
  ) async {
    const selection = TextSelectionContext(
      selectedText: 'signing',
      sourceId: 'book-1',
      sourceType: SourceType.book,
      contextText: 'The walkthrough explains signing up for a new account.',
    );
    translationService.resultOverride = const TranslationResult(
      originalText: 'signing',
      translatedText: 'регистрация',
      source: TranslationSource.remote,
      usageExamples: [
        'The walkthrough explains [[signing up]] for a new account.',
        'She is [[signing up]] for the course.',
        'They finished [[signing up]] before noon.',
      ],
    );

    await tester.pumpWidget(buildSubject(selection: selection));
    await tester.pump();

    expect(find.text('EXAMPLES'), findsOneWidget);
    expect(find.text('In this text'), findsOneWidget);
    expect(find.text('Example'), findsNothing);
  });

  testWidgets('uses only the sentence containing selection as reader example', (
    tester,
  ) async {
    const selection = TextSelectionContext(
      selectedText: 'sends',
      sourceId: 'book-1',
      sourceType: SourceType.book,
      contextText:
          'The alarm goes quiet. The robot sends us into a dizzying spin. We hit the wall.',
      markedContextText:
          'The alarm goes quiet. The robot [[sends]] us into a dizzying spin. We hit the wall.',
    );
    translationService.resultOverride = const TranslationResult(
      originalText: 'sends',
      translatedText: 'ввергает',
      source: TranslationSource.remote,
      sense: TranslationSense(partOfSpeech: 'verb'),
    );

    await tester.pumpWidget(buildSubject(selection: selection));
    await tester.pump();

    final renderedText = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((widget) => widget.text.toPlainText())
        .join('\n');

    expect(
      renderedText,
      contains('The robot sends us into a dizzying spin.'),
    );
    expect(renderedText, isNot(contains('The alarm goes quiet. The robot')));
    expect(renderedText, isNot(contains('We hit the wall.')));

    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pump();

    expect(
      dictionaryRepository.entries.single.context,
      'The robot [[sends]] us into a dizzying spin.',
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

    expect(find.text('искать'), findsWidgets);
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
      expressionTranslation: TranslationTextPair(
        source: 'kick off',
        target: 'начинать',
      ),
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

    expect(find.text('начать'), findsWidgets);
    final detailsText = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((widget) => widget.text.toPlainText())
        .join('\n');

    expect(find.text('Low confidence'), findsOneWidget);
    expect(richTextContains('Part of speech: noun'), isTrue);
    expect(richTextContains('Transcription: /θɪŋz/'), isTrue);
    expect(find.text('DEFINITIONS'), findsNothing);
    expect(
      detailsText.indexOf('Literal:'),
      lessThan(detailsText.indexOf('Source:')),
    );
    expect(richTextContains('To start an activity or process.'), isTrue);
    expect(richTextContains('Начать действие или процесс.'), isTrue);
    expect(richTextContains('Kick is used as part of kick off.'), isTrue);
    expect(richTextContains('В этом контексте подходит «начать».'), isTrue);
    expect(
      find.text(
        '"things" is used in the phrasal verb "kick off" here as "kick things off".',
      ),
      findsOneWidget,
    );
    expect(
      richTextContains('"things" is part of the phrasal verb'),
      isFalse,
    );
    expect(find.text('kick off'), findsWidgets);
    expect(richTextContains('lexical unit: kick off'), isFalse);
    expect(richTextContains('role: verb'), isFalse);
    expect(richTextContains('pattern: kick [object] off'), isFalse);
    expect(richTextContains('separable phrasal verb'), isFalse);
    expect(richTextContains('запустить'), isTrue);
    expect(richTextContains('пнуть вещи прочь'), isTrue);
    expect(richTextContains('Target: Начать действие или процесс.'), isTrue);
    expect(richTextContains('Things is an inserted object.'), isTrue);
  });

  testWidgets('keeps long translation result scrollable in a short sheet', (
    tester,
  ) async {
    const selection = TextSelectionContext(
      selectedText: 'sends',
      sourceId: 'book-1',
      sourceType: SourceType.book,
      contextText: 'It sends us into a dizzying spin.',
      markedContextText: 'It [[sends]] us into a dizzying spin.',
    );
    translationService.resultOverride = const TranslationResult(
      originalText: 'sends',
      translatedText: 'ввергает',
      source: TranslationSource.remote,
      answerType: TranslationAnswerType.expressionExplanation,
      sense: TranslationSense(
        partOfSpeech: 'verb',
        transcription: '/sendz/',
        sourceDefinition: 'To cause someone or something to enter a state.',
        targetDefinition:
            'Заставлять кого-либо или что-либо оказаться в состоянии.',
        sourceContextNote:
            'The verb takes an object and an into-phrase in this sentence.',
        targetContextNote:
            'В этом контексте важна конструкция перехода в состояние.',
      ),
      expression: TranslationExpression(
        term: 'sends',
        surface: 'sends us into a dizzying spin',
        lexicalUnit: 'send ... into',
        expressionType: 'verb_pattern',
      ),
      expressionTranslation: TranslationTextPair(
        source: 'send ... into',
        target: 'приводить кого-либо в определенное состояние',
      ),
      suggestedFullPhrase: TranslationTextPair(
        source: 'sends us into a dizzying spin',
        target: 'ввергает нас в головокружительное состояние',
      ),
      naturalEquivalents: ['cause', 'drive', 'throw'],
      literalTranslation: 'отправляет',
      usageExamples: [
        'It [[sends us into a dizzying spin]].',
        'The news [[sent him into a panic]].',
        'The joke [[sent the audience into fits of laughter]].',
      ],
      notes: TranslationTextPair(
        target: 'The expression section has its own save action.',
      ),
    );

    await tester.pumpWidget(buildSubject(selection: selection, height: 360));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.text('send ... into'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Save'), findsNWidgets(2));
  });

  testWidgets('shows irregular verb forms for translated verbs', (
    tester,
  ) async {
    const selection = TextSelectionContext(
      selectedText: 'went',
      sourceId: 'book-1',
      sourceType: SourceType.book,
    );
    translationService.resultOverride = const TranslationResult(
      originalText: 'went',
      translatedText: 'пошел',
      source: TranslationSource.remote,
      sense: TranslationSense(
        partOfSpeech: 'verb',
        lemma: 'go',
        lemmaTranscription: '/ɡoʊ/',
        grammaticalForm: 'past_tense',
      ),
    );

    await tester.pumpWidget(buildSubject(selection: selection));
    await tester.pump();

    final detailsText = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((widget) => widget.text.toPlainText())
        .join('\n');

    expect(find.textContaining('infinitive'), findsNothing);
    expect(detailsText, contains('Base form: go /ɡoʊ/'));
    expect(find.text('IRREGULAR VERB'), findsOneWidget);
    expect(find.text('go / went / gone'), findsOneWidget);
  });

  testWidgets(
    'renders expression translation without debug phrase metadata',
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

      expect(
        find.text(
          '"out" is part of the fixed expression "out of service" in this sentence.',
        ),
        findsOneWidget,
      );
      expect(detailsText, isNot(contains('Source: out of service')));
      expect(detailsText, contains('Target: не работает'));
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

    expect(find.text('в'), findsWidgets);
    expect(
      richTextContains(
        '"In" is part of the fixed expression "in other words" in this sentence.',
      ),
      isTrue,
    );
    expect(detailsText, isNot(contains('Source: in other words')));
    expect(detailsText, contains('Target: другими словами'));
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

  testWidgets('does not show dictionary save options on translation failure', (
    tester,
  ) async {
    translationService.shouldThrow = true;

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.widgetWithText(TextButton, 'Save'), findsNothing);
  });

  testWidgets('save to dictionary adds entry', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pump();

    expect(dictionaryRepository.entries, hasLength(1));
    expect(dictionaryRepository.entries.first.word, 'serendipity');
  });

  testWidgets('save to dictionary stores source anchor for exact selection', (
    tester,
  ) async {
    const selection = TextSelectionContext(
      selectedText: 'serendipity',
      sourceId: 'book-1',
      sourceType: SourceType.book,
      cfiRange: 'epubcfi(/6/4!/4/2,/1:0,/1:11)',
    );

    await tester.pumpWidget(buildSubject(selection: selection));
    await tester.pump();

    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pump();

    expect(dictionaryRepository.entries, hasLength(1));
    expect(dictionaryRepository.anchors, hasLength(1));
    expect(dictionaryRepository.anchors.single.text, 'serendipity');
    expect(
      dictionaryRepository.anchors.single.cfiRange,
      'epubcfi(/6/4!/4/2,/1:0,/1:11)',
    );
    expect(
      dictionaryRepository.anchors.single.kind,
      DictionaryAnchorKind.exactSelection,
    );
  });
}
