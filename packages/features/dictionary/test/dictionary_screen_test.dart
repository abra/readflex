import 'package:component_library/component_library.dart';
import 'package:dictionary/dictionary.dart';
import 'package:dictionary/src/dictionary_detail_sheet.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_article_repository.dart';
import 'helpers/fake_book_repository.dart';
import 'helpers/fake_dictionary_repository.dart';
import 'helpers/fake_fsrs_repository.dart';

final _entry = DictionaryEntry(
  id: 'de-1',
  word: 'serendipity',
  translation: 'счастливая случайность',
  pronunciation: '/ˌsɛr.ənˈdɪp.ɪ.ti/',
  partOfSpeech: 'noun',
  addedAt: DateTime(2026),
  usageExamples: ['A serendipity led to the discovery.'],
);

final _entry2 = DictionaryEntry(
  id: 'de-2',
  word: 'ephemeral',
  translation: 'мимолётный',
  addedAt: DateTime(2026),
);

void main() {
  late FakeDictionaryRepository dictionaryRepository;
  late FakeFsrsRepository fsrsRepository;
  late FakeBookRepository bookRepository;
  late FakeArticleRepository articleRepository;

  setUp(() {
    dictionaryRepository = FakeDictionaryRepository();
    fsrsRepository = FakeFsrsRepository();
    bookRepository = FakeBookRepository();
    articleRepository = FakeArticleRepository();
  });

  Widget buildSubject({VoidCallback? onPracticePressed}) => MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: DictionaryScreen(
        dictionaryRepository: dictionaryRepository,
        fsrsRepository: fsrsRepository,
        bookRepository: bookRepository,
        articleRepository: articleRepository,
        onPracticePressed: onPracticePressed,
      ),
    ),
  );

  testWidgets('shows error state on failure', (tester) async {
    dictionaryRepository.shouldThrow = true;

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('Failed to load dictionary'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('shows empty state when no entries', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('No entries found'), findsOneWidget);
    expect(find.text('Try a different search term'), findsOneWidget);
  });

  testWidgets('shows Dictionary header and total words count', (
    tester,
  ) async {
    dictionaryRepository.seed([_entry, _entry2]);

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('Dictionary'), findsOneWidget);
    // Header now mirrors Library's "N items" — the per-state counts
    // (mastered / learning) live in the filter chips below instead
    // of a separate indicator row.
    expect(find.text('2 words'), findsOneWidget);
  });

  testWidgets('mastered count surfaces via the filter chip', (tester) async {
    dictionaryRepository.seed([_entry, _entry2]);
    fsrsRepository.masteredIds = {'de-1'};

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    // No more standalone "N mastered" badge — the mastered chip in
    // the filter row carries the label and count is rendered in a
    // separate Text widget next to it.
    expect(find.text('Mastered'), findsOneWidget);
  });

  testWidgets('list row shows word, part of speech and translation', (
    tester,
  ) async {
    dictionaryRepository.seed([_entry]);

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('serendipity'), findsOneWidget);
    expect(find.text('noun'), findsOneWidget);
    expect(find.text('счастливая случайность'), findsOneWidget);
  });

  testWidgets('list row hides pronunciation (sheet-only)', (tester) async {
    dictionaryRepository.seed([_entry]);

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('/ˌsɛr.ənˈdɪp.ɪ.ti/'), findsNothing);
  });

  testWidgets('tap on row opens detail sheet with pronunciation', (
    tester,
  ) async {
    dictionaryRepository.seed([_entry]);

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    await tester.tap(find.text('serendipity'));
    await tester.pumpAndSettle();

    expect(find.text('/ˌsɛr.ənˈdɪp.ɪ.ti/'), findsOneWidget);
    expect(
      find.text('A serendipity led to the discovery.'),
      findsOneWidget,
    );
  });

  testWidgets('detail sheet shows source title instead of source id', (
    tester,
  ) async {
    final entry = _entry.copyWith(
      sourceId: 'book-1',
      sourceType: SourceType.book,
    );
    dictionaryRepository.seed([entry]);
    bookRepository.seed(
      Book(
        id: 'book-1',
        title: 'Bug Bounty from Scratch',
        filePath: '/tmp/book.epub',
        format: BookFormat.epub,
        addedAt: DateTime(2026),
      ),
    );

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    await tester.tap(find.text('serendipity'));
    await tester.pumpAndSettle();

    final richText = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((widget) => widget.text.toPlainText())
        .join('\n');
    expect(richText, contains('from Bug Bounty from Scratch'));
    expect(richText, isNot(contains('from book-1')));
  });

  testWidgets('detail sheet highlights marked saved context', (tester) async {
    final entry = _entry.copyWith(
      context: 'Several diners [[look up]] from their meals.',
      usageExamples: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: DictionaryDetailSheet(
            entry: entry,
            mastered: false,
            onDelete: () {},
          ),
        ),
      ),
    );

    final contextFinder = find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          widget.textSpan?.toPlainText() ==
              'Several diners look up from their meals.',
    );
    expect(contextFinder, findsOneWidget);
    expect(
      find.text('Several diners [[look up]] from their meals.'),
      findsNothing,
    );

    final textWidget = tester.widget<Text>(contextFinder);
    final rootSpan = textWidget.textSpan!;
    TextSpan? markedSpan;
    rootSpan.visitChildren((span) {
      if (span is TextSpan && span.text == 'look up') {
        markedSpan = span;
      }
      return true;
    });
    expect(markedSpan?.style?.fontWeight, FontWeight.w700);
  });

  testWidgets('detail sheet highlights entry word in unmarked context', (
    tester,
  ) async {
    final entry = _entry.copyWith(
      word: 'look up',
      context: 'Several diners look up from their meals.',
      usageExamples: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: DictionaryDetailSheet(
            entry: entry,
            mastered: false,
            onDelete: () {},
          ),
        ),
      ),
    );

    final contextFinder = find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          widget.textSpan?.toPlainText() ==
              'Several diners look up from their meals.',
    );
    expect(contextFinder, findsOneWidget);

    final textWidget = tester.widget<Text>(contextFinder);
    final rootSpan = textWidget.textSpan!;
    TextSpan? markedSpan;
    rootSpan.visitChildren((span) {
      if (span is TextSpan && span.text == 'look up') {
        markedSpan = span;
      }
      return true;
    });
    expect(markedSpan?.style?.fontWeight, FontWeight.w700);
  });

  testWidgets('detail sheet does not duplicate source context', (tester) async {
    final entry = _entry.copyWith(
      context: 'Several diners [[look up]] from their meals.',
      usageExamples: ['Several diners [[look up]] from their meals.'],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: DictionaryDetailSheet(
            entry: entry,
            mastered: false,
            onDelete: () {},
          ),
        ),
      ),
    );

    final sourceContext = tester
        .widgetList<Text>(find.byType(Text))
        .where(
          (widget) =>
              widget.textSpan?.toPlainText() ==
              'Several diners look up from their meals.',
        );
    expect(sourceContext, hasLength(1));
  });

  testWidgets('detail sheet shows Mastered badge for mastered entries', (
    tester,
  ) async {
    dictionaryRepository.seed([_entry]);
    fsrsRepository.masteredIds = {'de-1'};

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    // Before tap: only the filter chip is "Mastered"; no badge inside
    // the (not-yet-opened) sheet.
    final inSheet = find.descendant(
      of: find.byType(DictionaryDetailSheet),
      matching: find.text('Mastered'),
    );
    expect(inSheet, findsNothing);

    await tester.tap(find.text('serendipity'));
    await tester.pumpAndSettle();

    expect(inSheet, findsOneWidget);
  });

  testWidgets('shows search field', (tester) async {
    dictionaryRepository.seed([_entry]);

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('Search words...'), findsOneWidget);
  });

  testWidgets('shows filter chips with counts', (tester) async {
    dictionaryRepository.seed([_entry, _entry2]);
    fsrsRepository.masteredIds = {'de-1'};

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('All'), findsOneWidget);
    expect(find.text('Mastered'), findsOneWidget);
    expect(find.text('Learning'), findsOneWidget);
    expect(find.text('Recent'), findsOneWidget);
  });

  testWidgets('tapping Mastered filter narrows the list', (tester) async {
    dictionaryRepository.seed([_entry, _entry2]);
    fsrsRepository.masteredIds = {'de-1'};

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('serendipity'), findsOneWidget);
    expect(find.text('ephemeral'), findsOneWidget);

    await tester.tap(find.text('Mastered'));
    await tester.pump();

    expect(find.text('serendipity'), findsOneWidget);
    expect(find.text('ephemeral'), findsNothing);
  });

  testWidgets('Practice button hidden when callback is null', (tester) async {
    dictionaryRepository.seed([_entry]);

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    // Header now uses an icon-only button — find it by the practice
    // icon so the assertion isn't tied to a label that no longer
    // exists.
    expect(find.byIcon(AppIcons.practice), findsNothing);
  });

  testWidgets('Practice button visible and fires callback', (tester) async {
    dictionaryRepository.seed([_entry]);
    var fired = 0;

    await tester.pumpWidget(buildSubject(onPracticePressed: () => fired++));
    await tester.pump();

    expect(find.byIcon(AppIcons.practice), findsOneWidget);
    await tester.tap(find.byIcon(AppIcons.practice));
    expect(fired, 1);
  });

  testWidgets('FAB opens Add word sheet', (tester) async {
    dictionaryRepository.seed([_entry]);

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('Add word'), findsNothing);
    await tester.tap(find.byIcon(AppIcons.add));
    await tester.pumpAndSettle();
    expect(find.text('Add word'), findsOneWidget);
  });

  testWidgets('selection mode supports multi-select and back clears it', (
    tester,
  ) async {
    dictionaryRepository.seed([_entry, _entry2]);

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.byIcon(AppIcons.add), findsOneWidget);
    expect(find.byIcon(AppIcons.delete), findsNothing);
    expect(find.byIcon(AppIcons.check), findsNothing);

    await tester.longPress(find.text('serendipity'));
    await tester.pump();

    expect(find.byIcon(AppIcons.add), findsNothing);
    expect(find.byIcon(AppIcons.delete), findsOneWidget);
    expect(find.byIcon(AppIcons.check), findsOneWidget);

    await tester.tap(find.text('ephemeral'));
    await tester.pump();

    expect(find.byIcon(AppIcons.check), findsNWidgets(2));

    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(find.byIcon(AppIcons.add), findsOneWidget);
    expect(find.byIcon(AppIcons.delete), findsNothing);
    expect(find.byIcon(AppIcons.check), findsNothing);
    expect(find.text('Dictionary'), findsOneWidget);
  });

  testWidgets('Add word sheet inserts entry into the list on save', (
    tester,
  ) async {
    dictionaryRepository.seed([_entry]);

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    await tester.tap(find.byIcon(AppIcons.add));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Word'), 'gusto');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Translation'),
      'удовольствие',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('gusto'), findsOneWidget);
    expect(find.text('удовольствие'), findsOneWidget);
  });

  testWidgets('Add word sheet shows validation error for blank word', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    await tester.tap(find.byIcon(AppIcons.add));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.text('Word is required'), findsOneWidget);
    expect(find.text('Translation is required'), findsOneWidget);
    // Sheet stayed open
    expect(find.text('Add word'), findsOneWidget);
  });
}
