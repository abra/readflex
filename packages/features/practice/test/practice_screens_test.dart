import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:practice/practice.dart';
import 'package:practice/src/practice_settings_presets.dart';
import 'package:practice/src/practice_settings_sheet.dart';
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

  testWidgets('composite practice controls expose an accessible tap action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await seed();

      for (final (screen, control) in [
        (hub(), find.byKey(const ValueKey('practiceSource-b1'))),
        (wordsScreen(), find.byType(PracticeWordRow)),
        (highlightsScreen(), find.byType(PracticeHighlightRow)),
      ]) {
        await tester.pumpWidget(screen);
        await settle(tester);
        expect(
          tester
              .getSemantics(control)
              .getSemanticsData()
              .hasAction(
                SemanticsAction.tap,
              ),
          isTrue,
        );
      }

      await tester.pumpWidget(session());
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('reviewShowAnswer')));
      await tester.pumpAndSettle();
      final rating = tester.getSemantics(
        find.byKey(const ValueKey('reviewRate-good')),
      );
      expect(rating.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    } finally {
      semantics.dispose();
    }
  });

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

    for (final size in const [Size(1032, 1376), Size(1280, 800)]) {
      testWidgets('tablet separates the due action from its library: $size', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await seed();
        await tester.pumpWidget(hub());
        await settle(tester);

        final workspace = tester.getRect(
          find.byKey(const ValueKey('practiceWideWorkspace')),
        );
        final today = tester.getRect(find.byType(PracticeTodayCard));
        final collection = tester.getRect(
          find.byKey(const ValueKey('practiceWords')),
        );
        final action = tester.getRect(
          find.byKey(const ValueKey('practiceStartReview')),
        );
        expect(workspace.width, lessThanOrEqualTo(1200));
        expect(today.right, lessThan(collection.left));
        expect(today.contains(action.center), isTrue);
        expect(action.right, lessThanOrEqualTo(today.right));
        expect(tester.takeException(), isNull);

        await tester.tap(find.byKey(const ValueKey('practiceStartReview')));
        await tester.pump();
        expect(started.single, (sourceId: null, ahead: false));
      });
    }

    testWidgets('tablet workspace mirrors with Arabic reading direction', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1032, 1376);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await seed();
      await tester.pumpWidget(hub(locale: const Locale('ar')));
      await settle(tester);

      final today = tester.getRect(find.byType(PracticeTodayCard));
      final collection = tester.getRect(
        find.byKey(const ValueKey('practiceWords')),
      );
      expect(today.left, greaterThan(collection.right));
      expect(tester.takeException(), isNull);
    });

    testWidgets('tablet gives keyboard scrolling one primary source list', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1032, 1376);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final primary = ScrollController();
      addTearDown(primary.dispose);
      for (var index = 0; index < 20; index++) {
        final id = 'book-$index';
        await h.addBook(id, title: 'Saved book $index');
        await h.addWord('word $index', sourceId: id);
      }
      await tester.pumpWidget(
        h.app(PrimaryScrollController(controller: primary, child: hubScreen())),
      );
      await settle(tester);

      expect(primary.positions, hasLength(1));
      ScrollAction().invoke(
        const ScrollIntent(
          direction: AxisDirection.down,
          type: ScrollIncrementType.page,
        ),
        tester.element(find.byKey(const ValueKey('practiceWideWorkspace'))),
      );
      await tester.pumpAndSettle();
      expect(primary.offset, greaterThan(0));
      final offset = primary.offset;
      final viewport = tester.getRect(
        find.byKey(const ValueKey('practiceContent')),
      );
      final visible = find
          .byType(PracticeSourceRow)
          .evaluate()
          .firstWhere(
            (element) => viewport.contains(
              tester.getCenter(find.byWidget(element.widget)),
            ),
          );
      final visibleKey = visible.widget.key!;
      final originalCenter = tester.getCenter(find.byKey(visibleKey));

      tester.view.physicalSize = const Size(600, 900);
      await tester.pumpAndSettle();
      expect(primary.positions, hasLength(1));
      expect(primary.offset, closeTo(offset, .01));
      expect(
        tester
            .getRect(find.byKey(const ValueKey('practiceContent')))
            .contains(
              tester.getCenter(find.byKey(visibleKey)),
            ),
        isTrue,
      );

      tester.view.physicalSize = const Size(1032, 1376);
      await tester.pumpAndSettle();
      expect(primary.positions, hasLength(1));
      expect(primary.offset, closeTo(offset, .01));
      expect(
        tester.getCenter(find.byKey(visibleKey)).dy,
        closeTo(originalCenter.dy, .01),
      );
      expect(tester.takeException(), isNull);
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

  group('settings', () {
    final settingsButton = find.byKey(const ValueKey('practiceSettingsButton'));

    testWidgets('the app bar opens the sheet; a choice applies and the hub '
        'reloads when it closes', (tester) async {
      await seed();
      await tester.pumpWidget(hub());
      await settle(tester);
      expect(find.text('2 due'), findsWidgets);
      expect(find.byTooltip('Practice settings'), findsOneWidget);

      await tester.tap(settingsButton);
      await tester.pumpAndSettle();
      expect(find.text('Practice settings'), findsOneWidget);
      expect(find.byKey(const ValueKey('practiceSettingsNewCards')), findsOne);
      expect(find.byKey(const ValueKey('practiceSettingsReview')), findsOne);
      expect(find.byKey(const ValueKey('practiceSettingsMemory')), findsOne);

      await tester.tap(find.text('Vocabulary only'));
      await tester.pumpAndSettle();
      expect(h.preferences.current.practiceReviewHighlights, isFalse);
      await tester.tap(find.text('40'));
      await tester.tap(find.text('Stronger'));
      await tester.pumpAndSettle();
      expect(h.preferences.current.practiceNewCardsPerDay, 40);
      expect(h.preferences.current.practiceDesiredRetention, 0.95);

      await tester.tap(find.byTooltip('Close'));
      await settle(tester);
      // The highlight no longer counts as due.
      expect(find.text('Practice settings'), findsNothing);
      expect(find.text('1 due'), findsWidgets);
    });

    testWidgets('reopening shows the stored choices', (tester) async {
      await h.preferences.update(
        (p) => p.copyWith(
          practiceNewCardsPerDay: 10,
          practiceReviewHighlights: false,
          practiceDesiredRetention: 0.8,
        ),
      );
      await tester.pumpWidget(hub());
      await settle(tester);
      await tester.tap(settingsButton);
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<AppChoiceControl<int>>(
              find.byKey(const ValueKey('practiceSettingsNewCards')),
            )
            .selected,
        10,
      );
      expect(
        tester
            .widget<AppChoiceControl<bool>>(
              find.byKey(const ValueKey('practiceSettingsReview')),
            )
            .selected,
        isFalse,
      );
      expect(
        tester
            .widget<AppChoiceControl<PracticeMemoryTarget>>(
              find.byKey(const ValueKey('practiceSettingsMemory')),
            )
            .selected,
        PracticeMemoryTarget.lighter,
      );
    });

    for (final locale in ReadflexSupportedLocales.locales) {
      testWidgets('200% text at 320x568 without overflow: $locale', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          hub(locale: locale, textScaler: const TextScaler.linear(2)),
        );
        await settle(tester);
        await tester.tap(settingsButton);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(PracticeSettingsSheet), findsOneWidget);
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('practiceSettingsMemoryHint')),
          200,
          scrollable: find
              .descendant(
                of: find.byType(PracticeSettingsSheet),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(tester.takeException(), isNull);
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

        final appBar = find.byType(AppNavigationBar);
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
          of: find.byType(AppNavigationBar),
          matching: find.text('Практика'),
        ),
        findsOneWidget,
      );
    });
  });

  group('words', () {
    testWidgets('resizing the search toolbar retains its query and focus', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await seed();
      await h.addWord('desert');
      await tester.pumpWidget(wordsScreen());
      await settle(tester);
      await tester.enterText(find.byType(EditableText), 'spice');
      await tester.pumpAndSettle();
      final editor = tester.element(find.byType(EditableText));
      final focus = tester
          .widget<EditableText>(find.byType(EditableText))
          .focusNode;
      expect(focus.hasFocus, isTrue);
      expect(find.text('desert'), findsNothing);

      for (final size in const [Size(600, 800), Size(1200, 800)]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        expect(tester.element(find.byType(EditableText)), same(editor));
        expect(focus.hasFocus, isTrue);
        expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .controller
              .text,
          'spice',
        );
        expect(find.byType(PracticeWordRow), findsOneWidget);
        expect(find.text('desert'), findsNothing);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('lists words, opens the sheet, removes', (tester) async {
      await seed();
      await tester.pumpWidget(wordsScreen());
      await settle(tester);

      expect(find.textContaining('spice'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(PracticeWordRow),
          matching: find.text('Dune'),
        ),
        findsOneWidget,
      );
      expect(find.text('New'), findsOneWidget);

      await tester.tap(find.textContaining('spice'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(ActionBottomSheetLayout),
          matching: find.text('пряность'),
        ),
        findsOneWidget,
      );
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

    testWidgets('long details scroll while word actions stay reachable', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await h.addBook('b1');
      await h.addWord(
        'word',
        sourceId: 'b1',
        context: List.filled(
          40,
          'A long sentence in its original context.',
        ).join(' '),
        contextTranslation: List.filled(40, 'Its saved translation.').join(' '),
      );
      await tester.pumpWidget(wordsScreen(ts: const TextScaler.linear(2)));
      await settle(tester);
      await tester.tap(find.text('word'));
      await tester.pumpAndSettle();

      final action = tester.getRect(find.text('Open in book'));
      expect(action.bottom, lessThanOrEqualTo(568));
      await tester.drag(
        find.byKey(const ValueKey('practiceWordDetails')),
        const Offset(0, -250),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(find.text('Open in book')), action);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Open in book'));
      await settle(tester);
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
      expect(
        find.descendant(
          of: find.byType(PracticeHighlightRow),
          matching: find.text('Chapter 1'),
        ),
        findsOneWidget,
      );
      expect(find.text('New'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('practiceColor-green')));
      await tester.pumpAndSettle();
      expect(find.text('No matches'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('practiceColor-all')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Fear is the mind-killer.'));
      await tester.pump();
      expect(opened.single.$1, 'b1');
    });

    testWidgets('long collections build only visible highlight rows', (
      tester,
    ) async {
      await h.addBook('b1', title: 'Dune');
      for (var index = 0; index < 80; index++) {
        await h.addHighlight('b1', 'Saved passage $index.');
      }
      await tester.pumpWidget(highlightsScreen());
      await settle(tester);

      expect(find.byType(PracticeHighlightRow).evaluate().length, lessThan(20));
      await tester.scrollUntilVisible(
        find.text('Saved passage 0.'),
        400,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('practiceHighlightsList')),
          matching: find.byType(Scrollable),
        ),
        maxScrolls: 40,
      );
      expect(find.text('Saved passage 0.'), findsOneWidget);
      expect(tester.takeException(), isNull);
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
    testWidgets('tablet study and summary keep a focused reading measure', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await h.addWord('spice', translation: 'пряность');
      await tester.pumpWidget(session());
      await settle(tester);

      final card = tester.getRect(
        find.byKey(const ValueKey('reviewStudyCard')),
      );
      final reveal = tester.getRect(
        find.byKey(const ValueKey('reviewShowAnswer')),
      );
      expect(card.width, lessThanOrEqualTo(640));
      expect(card.center.dx, closeTo(640, .01));
      expect(reveal.width, closeTo(card.width, .01));
      expect(reveal.bottom, greaterThan(720));
      await tester.tap(find.byKey(const ValueKey('reviewShowAnswer')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('reviewRate-good')));
      await settle(tester);

      final summary = tester.getRect(
        find.byKey(const ValueKey('reviewSummaryCard')),
      );
      final done = tester.getRect(find.byKey(const ValueKey('reviewDone')));
      expect(summary.width, lessThanOrEqualTo(480));
      expect(summary.center.dx, closeTo(640, .01));
      expect(summary.contains(done.center), isFalse);
      expect(done.bottom, greaterThan(720));
      expect(done.width, closeTo(reveal.width, .01));
      expect(done.center.dx, closeTo(640, .01));
      expect(
        find.byKey(const ValueKey('reviewDone')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('phone RTL large text keeps every rating in thumb reach', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await h.addWord('كلمة', translation: 'A saved meaning');
      await tester.pumpWidget(
        session(locale: const Locale('ar'), ts: const TextScaler.linear(2)),
      );
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('reviewShowAnswer')));
      await tester.pumpAndSettle();

      Rect? previous;
      for (final rating in ['again', 'hard', 'good']) {
        final rect = tester.getRect(find.byKey(ValueKey('reviewRate-$rating')));
        expect(rect.width, greaterThanOrEqualTo(48));
        expect(rect.height, greaterThanOrEqualTo(48));
        expect(rect.bottom, lessThanOrEqualTo(568));
        if (previous case final above?) {
          expect(rect.top, greaterThan(above.bottom));
        }
        previous = rect;
      }
      expect(tester.takeException(), isNull);
    });

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
      expect(find.byKey(const ValueKey('reviewShowAnswer')), findsNothing);
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
      expect(find.byKey(const ValueKey('reviewShowAnswer')), findsNothing);
      expect(find.text('Litany'), findsOneWidget);
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
        expect(find.byKey(const ValueKey('reviewShowAnswer')), findsNothing);
        for (final rating in ['keep', 'showLess']) {
          expect(
            find.byKey(ValueKey('reviewRate-$rating')).hitTestable(),
            findsOneWidget,
          );
        }
        await tester.tap(find.byKey(const ValueKey('reviewRate-showLess')));
        await settle(tester);
        expect(find.byType(ReviewSessionSummary), findsOneWidget);
        expect(
          find.byKey(const ValueKey('reviewDone')).hitTestable(),
          findsOneWidget,
        );
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
