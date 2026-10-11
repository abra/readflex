import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:reader_webview/reader_webview.dart';

import '../support/reading_fixture.dart';
import '../support/reader_test_platform.dart';
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
    await app.readerServer.start();
  });
  tearDown(() => app.dispose());

  testWidgets('a book read for the first time is in Continue reading '
      'before the reader closes', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final previous = InAppWebViewPlatform.instance;
    final platform = ReaderTestPlatform();
    InAppWebViewPlatform.instance = platform;
    addTearDown(() {
      if (previous != null) InAppWebViewPlatform.instance = previous;
    });
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
    await waitForUi(
      tester,
      () =>
          platform.views.isNotEmpty &&
          platform.views.single.controller.handlers.containsKey('onLoadEnd'),
      description: 'reader platform mounted',
    );
    final handlers = platform.views.single.controller.handlers;
    handlers['onLoadEnd']!([]);
    await tester.pump();
    handlers['onRelocated']!([
      {'cfi': 'epubcfi(/6/4!/4/2/1:0)', 'percentage': 0.3},
    ]);

    // The Library behind the reader picks the book up while still covered.
    await waitForUi(
      tester,
      () => offstageCard.evaluate().isNotEmpty,
      description: 'Continue reading card behind the reader',
    );
    expect(card, findsNothing, reason: 'the reader still covers the Library');

    final readerContext = tester.element(find.byType(BookReaderWebView));
    GoRouter.of(readerContext).pop();
    await tester.pump();

    // The first frame after closing already shows the book in the card.
    expect(card, findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.text(ReadingFixture.bookTitle)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('30%')),
      findsOneWidget,
    );
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
    expect(
      find.descendant(of: card, matching: find.text('30%')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('progress saved while reading eases in on return', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final previous = InAppWebViewPlatform.instance;
    final platform = ReaderTestPlatform();
    InAppWebViewPlatform.instance = platform;
    addTearDown(() {
      if (previous != null) InAppWebViewPlatform.instance = previous;
    });
    await tester.runAsync(() async {
      await app.bookRepository.updateReadingPosition(
        app.book!.id,
        cfi: 'epubcfi(/6/4!/4/2/1:0)',
        progress: 0.3,
      );
      await app.bookRepository.markOpened(app.book!.id, DateTime(2026, 10, 7));
    });
    final card = find.byKey(const ValueKey('libraryContinueReadingCard'));
    final track = find.byKey(const ValueKey('libraryContinueReadingProgress'));
    final fill = find.byKey(
      const ValueKey('libraryContinueReadingProgressFill'),
    );
    final offstagePercent = find.descendant(
      of: find.byKey(
        const ValueKey('libraryContinueReadingCard'),
        skipOffstage: false,
      ),
      matching: find.text('60%', skipOffstage: false),
    );
    double fillFraction() =>
        tester.getSize(fill).width / tester.getSize(track).width;

    await tester.pumpWidget(app.widget);
    await waitForUi(
      tester,
      () => card.evaluate().isNotEmpty,
      description: 'Continue reading card',
    );
    await tester.pump(const Duration(seconds: 1));
    expect(fillFraction(), closeTo(.3, .01));

    await tapUi(tester, card);
    await waitForUi(
      tester,
      () =>
          platform.views.isNotEmpty &&
          platform.views.single.controller.handlers.containsKey('onLoadEnd'),
      description: 'reader platform mounted',
    );
    final handlers = platform.views.single.controller.handlers;
    handlers['onLoadEnd']!([]);
    await tester.pump();
    handlers['onRelocated']!([
      {'cfi': 'epubcfi(/6/8!/4/2/1:0)', 'percentage': 0.6},
    ]);
    // A later save is debounced; the Library behind the reader shows it.
    await waitForUi(
      tester,
      () => offstagePercent.evaluate().isNotEmpty,
      description: 'saved progress behind the reader',
    );
    // Keep reading well past the fill's duration before closing the book,
    // as a reader does: the change must still play on return.
    await tester.pump(const Duration(seconds: 2));

    GoRouter.of(tester.element(find.byType(BookReaderWebView))).pop();
    await tester.pump();
    expect(
      fillFraction(),
      closeTo(.3, .01),
      reason: 'the fill waits for the Library to show',
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(fillFraction(), greaterThan(.3));
    expect(fillFraction(), lessThan(.6));
    await tester.pump(const Duration(milliseconds: 200));
    expect(fillFraction(), closeTo(.6, .01));

    // The fallback refresh after the route returns leaves the fill in place.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(fillFraction(), closeTo(.6, .01));
    expect(tester.takeException(), isNull);
  });
}
