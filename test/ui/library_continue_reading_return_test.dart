import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:reader/src/reader_bloc.dart';
import 'package:pagecraft/all_formats.dart' show TextColumnPage, TextPagesView;

import '../support/reading_fixture.dart';
import '../support/ui_test_app.dart';
import '../support/ui_test_driver.dart';

/// The reader reports each saved position while it covers the Library, so a
/// book read for the first time is already in Continue reading when the
/// reader closes: the user never sees it move there. A changed progress waits
/// and eases in once the Library shows.
void main() {
  late UiTestApp app;
  setUp(() async {
    app = await UiTestApp.create();
  });
  tearDown(() => app.dispose());

  Future<void> waitForPages(WidgetTester tester) => waitForUi(
    tester,
    () => find.byType(TextColumnPage).evaluate().isNotEmpty,
    description: 'the first page',
    timeout: const Duration(seconds: 30),
  );

  ReaderBloc readerBloc(WidgetTester tester) =>
      tester.element(find.byType(TextPagesView)).read<ReaderBloc>();

  /// Turns to the next page and waits until the reader is past [progress].
  Future<double> readPast(WidgetTester tester, double progress) async {
    await tester.fling(
      find.byType(TextPagesView),
      const Offset(-300, 0),
      1000,
    );
    await waitForUi(
      tester,
      () => readerBloc(tester).state.document!.readingProgress > progress,
      description: 'the next page',
      timeout: const Duration(seconds: 30),
    );
    // The fling may cross a page before its final scroll position settles.
    await tester.pumpAndSettle();
    return readerBloc(tester).state.document!.readingProgress;
  }

  testWidgets('a book read for the first time is in Continue reading '
      'before the reader closes', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final card = find.byKey(const ValueKey('libraryContinueReadingCard'));
    final offstageCard = find.byKey(
      const ValueKey('libraryContinueReadingCard'),
      skipOffstage: false,
    );

    await tester.pumpWidget(app.widget);
    final tile = find.byKey(ValueKey('library-grid-${app.book!.id}'));
    await waitForUi(
      tester,
      () => tile.evaluate().isNotEmpty,
      description: 'library tile',
    );
    expect(app.book!.readingProgress, 0);
    expect(card, findsNothing);
    // Let the list's entrance animation finish, as it has long before a
    // reader taps a book; a covered route pauses its tickers.
    await tester.pump(const Duration(seconds: 1));

    await tapUi(tester, tile);
    await waitForPages(tester);
    final progress = await readPast(tester, 0);
    final percent = '${(progress * 100).round()}%';

    // The Library behind the reader picks the book up while still covered.
    await waitForUi(
      tester,
      () => find
          .descendant(
            of: offstageCard,
            matching: find.text(percent, skipOffstage: false),
          )
          .evaluate()
          .isNotEmpty,
      description: 'saved Continue reading progress behind the reader',
    );
    expect(card, findsNothing, reason: 'the reader still covers the Library');

    GoRouter.of(tester.element(find.byType(TextPagesView))).pop();
    await tester.pump();

    // The first frame after closing already shows the book in the card.
    expect(card, findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.text(ReadingFixture.bookTitle)),
      findsOneWidget,
    );
    expect(find.descendant(of: card, matching: find.text(percent)), findsOne);
    expect(tile, findsNothing, reason: 'the card is the book\'s only place');
    final cardRect = tester.getRect(card);

    // The fallback refresh after the route returns changes nothing.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    expect(card, findsOneWidget);
    expect(tester.getRect(card), cardRect);
    expect(find.descendant(of: card, matching: find.text(percent)), findsOne);
    expect(tester.takeException(), isNull);
  });

  testWidgets('progress saved while reading eases in on return', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final card = find.byKey(const ValueKey('libraryContinueReadingCard'));
    final offstageCard = find.byKey(
      const ValueKey('libraryContinueReadingCard'),
      skipOffstage: false,
    );
    final track = find.byKey(const ValueKey('libraryContinueReadingProgress'));
    final fill = find.byKey(
      const ValueKey('libraryContinueReadingProgressFill'),
    );
    double fillFraction() =>
        tester.getSize(fill).width / tester.getSize(track).width;

    await tester.pumpWidget(app.widget);
    final tile = find.byKey(ValueKey('library-grid-${app.book!.id}'));
    await waitForUi(
      tester,
      () => tile.evaluate().isNotEmpty,
      description: 'library tile',
    );
    await tester.pump(const Duration(seconds: 1));
    // A first read puts the book in Continue reading.
    await tapUi(tester, tile);
    await waitForPages(tester);
    final before = await readPast(tester, 0);
    await waitForUi(
      tester,
      () => find
          .descendant(
            of: offstageCard,
            matching: find.text(
              '${(before * 100).round()}%',
              skipOffstage: false,
            ),
          )
          .evaluate()
          .isNotEmpty,
      description: 'first saved progress behind the reader',
    );
    GoRouter.of(tester.element(find.byType(TextPagesView))).pop();
    await tester.pumpAndSettle();
    expect(fillFraction(), closeTo(before, .01));

    await tapUi(tester, card);
    await waitForPages(tester);
    // A later save is debounced; the Library behind the reader shows it.
    final after = await readPast(tester, before);
    final percent = '${(after * 100).round()}%';
    await waitForUi(
      tester,
      () => find
          .descendant(
            of: offstageCard,
            matching: find.text(percent, skipOffstage: false),
          )
          .evaluate()
          .isNotEmpty,
      description: 'saved progress behind the reader',
    );
    // Keep reading well past the fill's duration before closing the book,
    // as a reader does: the change must still play on return.
    await tester.pump(const Duration(seconds: 2));

    GoRouter.of(tester.element(find.byType(TextPagesView))).pop();
    await tester.pump();
    expect(
      fillFraction(),
      closeTo(before, .01),
      reason: 'the fill waits for the Library to show',
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(fillFraction(), greaterThan(before));
    expect(fillFraction(), lessThan(after));
    await tester.pump(const Duration(milliseconds: 200));
    expect(fillFraction(), closeTo(after, .01));

    // The fallback refresh after the route returns leaves the fill in place.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(fillFraction(), closeTo(after, .01));
    expect(tester.takeException(), isNull);
  });
}
