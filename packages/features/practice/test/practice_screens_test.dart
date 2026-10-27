import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:practice/practice.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'helpers/practice_harness.dart';

void main() {
  late PracticeHarness h;
  late List<({String? sourceId, bool ahead})> started;
  var words = 0;
  var highlights = 0;
  late List<(String, String?)> opened;

  setUp(() async {
    h = await PracticeHarness.create();
    started = [];
    opened = [];
    words = 0;
    highlights = 0;
  });
  tearDown(() => h.dispose());

  PracticeScreen hubScreen() => PracticeScreen(
    fsrsRepository: h.fsrs,
    dictionaryRepository: h.dictionary,
    highlightRepository: h.highlights,
    bookRepository: h.books,
    articleRepository: h.articles,
    preferencesService: h.preferences,
    onStartReview: ({sourceId, ahead = false}) async =>
        started.add((sourceId: sourceId, ahead: ahead)),
    onWordsPressed: () async => words++,
    onHighlightsPressed: () async => highlights++,
  );

  Widget hub({Locale locale = const Locale('en'), TextScaler? textScaler}) =>
      h.app(
        hubScreen(),
        locale: locale,
        textScaler: textScaler ?? TextScaler.noScaling,
      );

  PracticeWordsScreen wordsOnly() => PracticeWordsScreen(
    dictionaryRepository: h.dictionary,
    fsrsRepository: h.fsrs,
    bookRepository: h.books,
    articleRepository: h.articles,
    onOpenInSource: (id, cfi) async => opened.add((id, cfi)),
  );

  Widget wordsScreen({Locale locale = const Locale('en'), TextScaler? ts}) => h
      .app(wordsOnly(), locale: locale, textScaler: ts ?? TextScaler.noScaling);

  PracticeHighlightsScreen highlightsOnly() => PracticeHighlightsScreen(
    highlightRepository: h.highlights,
    fsrsRepository: h.fsrs,
    bookRepository: h.books,
    articleRepository: h.articles,
    onOpenInSource: (hl) async => opened.add((hl.sourceId, hl.cfiRange)),
  );

  Widget highlightsScreen({
    Locale locale = const Locale('en'),
    TextScaler? ts,
  }) => h.app(
    highlightsOnly(),
    locale: locale,
    textScaler: ts ?? TextScaler.noScaling,
  );

  Widget session({
    Locale locale = const Locale('en'),
    TextScaler? ts,
    bool ahead = false,
  }) => h.app(
    ReviewSessionScreen(
      fsrsRepository: h.fsrs,
      dictionaryRepository: h.dictionary,
      highlightRepository: h.highlights,
      bookRepository: h.books,
      articleRepository: h.articles,
      preferencesService: h.preferences,
      onOpenInSource: (id, cfi) async => opened.add((id, cfi)),
      ahead: ahead,
    ),
    locale: locale,
    textScaler: ts ?? TextScaler.noScaling,
  );

  Future<void> seed() async {
    await h.addBook('b1', title: 'Dune');
    await h.addWord(
      'spice',
      translation: 'пряность',
      sourceId: 'b1',
      context: 'The spice must flow.',
      base: 'специя',
      contextTranslation: 'Пряность должна течь.',
    );
    await h.addHighlight('b1', 'Fear is the mind-killer.', note: 'Litany');
  }

  group('hub', () {
    testWidgets('empty: nothing to practice, no command, back only', (
      tester,
    ) async {
      await tester.pumpWidget(hub());
      await settle(tester);

      expect(find.text('Nothing to practice yet'), findsWidgets);
      expect(find.byKey(const ValueKey('practiceStartReview')), findsNothing);
      expect(find.byKey(const ValueKey('practiceEmptyState')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('practiceEmptyState')),
          matching: find.byType(ButtonStyleButton),
        ),
        findsNothing,
      );
    });

    testWidgets('with cards: today, collections, by book, Start review', (
      tester,
    ) async {
      await seed();
      await tester.pumpWidget(hub());
      await settle(tester);

      expect(find.text('2 due'), findsWidgets);
      expect(find.text('Vocabulary'), findsOneWidget);
      expect(find.text('Highlights'), findsOneWidget);
      expect(find.text('Dune'), findsOneWidget);
      expect(find.text('1 word · 1 highlight'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('practiceStartReview')));
      await tester.pump();
      expect(started.single, (sourceId: null, ahead: false));

      await tester.tap(find.byKey(const ValueKey('practiceSource-b1')));
      await tester.pump();
      expect(started.last, (sourceId: 'b1', ahead: false));

      await tester.tap(find.byKey(const ValueKey('practiceWords')));
      await tester.tap(find.byKey(const ValueKey('practiceHighlights')));
      expect(words, 1);
      expect(highlights, 1);
    });

    testWidgets('Start review appears with the content, at full size', (
      tester,
    ) async {
      await seed();
      await tester.pumpWidget(hub());
      // Let the load finish, then take the first frame that shows content.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      final start = find.byKey(const ValueKey('practiceStartReview'));
      expect(find.byKey(const ValueKey('practiceTodayCard')), findsOneWidget);
      expect(start, findsOneWidget);
      final firstFrame = tester.getRect(start);

      await tester.pumpAndSettle();

      expect(tester.getRect(start), firstFrame);
    });

    testWidgets('caught up offers Review ahead', (tester) async {
      await seed();
      final due = await h.fsrs.getDueItems();
      for (final item in due) {
        await h.review(item.itemId, item.itemType, Rating.easy);
      }
      await tester.pumpWidget(hub());
      await settle(tester);

      expect(find.text('All caught up'), findsWidgets);
      expect(find.text('Review ahead'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('practiceStartReview')));
      await tester.pump();
      expect(started.single.ahead, isTrue);
    });

    for (final locale in ReadflexSupportedLocales.locales) {
      testWidgets('200% text at 320x568 without overflow: $locale', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await seed();
        await tester.pumpWidget(
          hub(locale: locale, textScaler: const TextScaler.linear(2)),
        );
        await settle(tester);
        expect(tester.takeException(), isNull);
        await scrollTo(tester, const ValueKey('practiceSource-b1'));
        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const ValueKey('practiceStartReview')),
          findsOneWidget,
        );
      });
    }
  });

  group('app bar', () {
    for (final (name, screen, title) in [
      ('hub', hubScreen, 'Practice'),
      ('words', wordsOnly, 'Vocabulary'),
      ('highlights', highlightsOnly, 'Highlights'),
    ]) {
      testWidgets('$name names itself and the app chevron goes back', (
        tester,
      ) async {
        await seed();
        await tester.pumpWidget(h.app(_Launcher(screen: screen)));
        await tester.tap(find.text('Open'));
        await settle(tester);

        final appBar = find.byType(AppBar);
        expect(
          find.descendant(of: appBar, matching: find.text(title)),
          findsOneWidget,
          reason: name,
        );
        expect(
          find.descendant(of: appBar, matching: find.byType(AppBackButton)),
          findsOneWidget,
          reason: name,
        );
        expect(find.byType(BackButton), findsNothing, reason: name);
        expect(find.byTooltip('Back'), findsOneWidget, reason: name);

        await tester.tap(find.byType(AppBackButton));
        await tester.pumpAndSettle();
        expect(appBar, findsNothing, reason: name);
        expect(find.text('Open'), findsOneWidget, reason: name);
      });
    }

    testWidgets('the back tooltip is localized', (tester) async {
      await tester.pumpWidget(
        h.app(_Launcher(screen: hubScreen), locale: const Locale('ru')),
      );
      await tester.tap(find.text('Open'));
      await settle(tester);

      expect(find.byTooltip('Назад'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Практика'),
        ),
        findsOneWidget,
      );
    });
  });

  group('words', () {
    testWidgets('lists words, opens the sheet, removes', (tester) async {
      await seed();
      await tester.pumpWidget(wordsScreen());
      await settle(tester);

      expect(find.textContaining('spice'), findsOneWidget);
      expect(find.textContaining('Dune · New'), findsOneWidget);

      await tester.tap(find.textContaining('spice'));
      await tester.pumpAndSettle();
      expect(find.text('пряность'), findsOneWidget);
      expect(find.text('специя'), findsOneWidget);
      expect(find.text('The spice must flow.'), findsOneWidget);

      await tester.tap(find.text('Open in book'));
      await tester.pumpAndSettle();
      expect(opened.single.$1, 'b1');
      expect(opened.single.$2, isNotNull);
      await settle(tester);

      await tester.tap(find.textContaining('spice'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove from Vocabulary'));
      await settle(tester);
      expect(find.text('No vocabulary yet'), findsOneWidget);
    });

    testWidgets('empty state', (tester) async {
      await tester.pumpWidget(wordsScreen());
      await settle(tester);
      expect(find.text('No vocabulary yet'), findsOneWidget);
    });

    for (final locale in const [Locale('en'), Locale('de'), Locale('ar')]) {
      testWidgets('200% text fits: $locale', (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await seed();
        await tester.pumpWidget(
          wordsScreen(locale: locale, ts: const TextScaler.linear(2)),
        );
        await settle(tester);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('highlights', () {
    testWidgets('lists by source and opens', (tester) async {
      await seed();
      await tester.pumpWidget(highlightsScreen());
      await settle(tester);

      expect(find.text('Dune'), findsOneWidget);
      expect(find.text('Fear is the mind-killer.'), findsOneWidget);
      expect(find.text('Litany'), findsOneWidget);
      expect(find.textContaining('Chapter 1 · New'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('practiceColor-green')));
      await tester.pumpAndSettle();
      expect(find.text('No matches'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('practiceColor-all')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Fear is the mind-killer.'));
      await tester.pump();
      expect(opened.single.$1, 'b1');
    });

    for (final locale in const [Locale('en'), Locale('de'), Locale('ar')]) {
      testWidgets('200% text fits: $locale', (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await seed();
        await tester.pumpWidget(
          highlightsScreen(locale: locale, ts: const TextScaler.linear(2)),
        );
        await settle(tester);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('session', () {
    testWidgets('word then highlight, ratings, summary, review again', (
      tester,
    ) async {
      await seed();
      await tester.pumpWidget(session());
      await settle(tester);

      expect(find.text('1 of 2'), findsOneWidget);
      expect(find.byKey(const ValueKey('reviewWord')), findsOneWidget);
      expect(find.byKey(const ValueKey('reviewAnswer')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('reviewShowAnswer')));
      await tester.pumpAndSettle();
      expect(find.text('пряность'), findsOneWidget);
      expect(find.text('Пряность должна течь.'), findsOneWidget);
      expect(find.byKey(const ValueKey('reviewRate-again')), findsOneWidget);
      expect(find.byKey(const ValueKey('reviewRate-good')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('reviewRate-again')));
      await settle(tester);
      expect(find.text('2 of 2'), findsOneWidget);
      expect(find.byKey(const ValueKey('reviewQuote')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('reviewShowAnswer')));
      await tester.pumpAndSettle();
      expect(find.text('Litany'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('reviewRate-keep')));
      await settle(tester);

      expect(find.text('Session complete'), findsOneWidget);
      expect(find.text('2 reviewed · 1 known · 1 again'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('reviewAgain')));
      await tester.pumpAndSettle();
      expect(find.text('1 of 1'), findsOneWidget);
      expect(find.byKey(const ValueKey('reviewWord')), findsOneWidget);
    });

    testWidgets('menu opens the source and removes a card', (tester) async {
      await seed();
      await tester.pumpWidget(session());
      await settle(tester);

      await tester.tap(find.byKey(const ValueKey('reviewMenu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('reviewMenuOpen')));
      await tester.pumpAndSettle();
      expect(opened.single.$1, 'b1');

      await tester.tap(find.byKey(const ValueKey('reviewMenu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('reviewMenuRemove')));
      await settle(tester);
      expect(find.text('1 of 1'), findsOneWidget);
      expect(find.byKey(const ValueKey('reviewQuote')), findsOneWidget);
    });

    testWidgets('nothing due shows the empty state', (tester) async {
      await tester.pumpWidget(session());
      await settle(tester);
      expect(find.text('All caught up'), findsOneWidget);
    });

    for (final locale in ReadflexSupportedLocales.locales) {
      testWidgets('200% text at 320x568 without overflow: $locale', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await seed();
        await tester.pumpWidget(
          session(locale: locale, ts: const TextScaler.linear(2)),
        );
        await settle(tester);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const ValueKey('reviewShowAnswer')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const ValueKey('reviewRate-good')));
        await settle(tester);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const ValueKey('reviewShowAnswer')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });
}

/// A home page that pushes [screen], so its app bar has a route to go back to.
class _Launcher extends StatelessWidget {
  const _Launcher({required this.screen});

  final Widget Function() screen;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => screen())),
        child: const Text('Open'),
      ),
    ),
  );
}
