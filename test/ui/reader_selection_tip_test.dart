import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:reader/reader.dart';
import 'package:reader/src/reader_selection_cubit.dart';
import 'package:reader/src/reader_selection_tip.dart';
import 'package:pagecraft/all_formats.dart' show TextColumnPage, TextPagesView;

import '../support/ui_test_app.dart';
import '../support/ui_test_driver.dart';
import 'golden_support.dart';

/// The one-time "Press and hold a word" tip in the real reader: it waits for
/// the painted page, a page turn hides it for the session, a selection ends
/// it for good, and a returning reader never sees it.
void main() {
  setUpAll(loadUiFonts);

  final tip = find.byType(ReaderSelectionTipCard);

  /// Mounts the reader on the fixture book; its page is still loading.
  Future<UiTestApp> openBook(
    WidgetTester tester, {
    VisualProfile profile = VisualProfile.phone,
    bool tipDismissed = false,
  }) async {
    final app = (await tester.runAsync(
      () => UiTestApp.create(readerSelectionTipDismissed: tipDismissed),
    ))!;
    addTearDown(app.dispose);
    await pumpGoldenSurface(
      tester,
      profile,
      (_) => ReaderScreen(
        sourceId: app.book!.id,
        bookRepository: app.bookRepository,
        highlightRepository: app.highlightRepository,
        preferencesService: app.preferencesService,
        screenControlService: app.screenControlService,
        textActions: const [],
        initialSource: app.book,
      ),
    );
    return app;
  }

  /// Waits for the reader's first page.
  Future<void> pagePainted(WidgetTester tester) async {
    await waitForUi(
      tester,
      () => find.byType(TextColumnPage).evaluate().isNotEmpty,
      description: 'the first page',
      timeout: const Duration(seconds: 30),
    );
    await tester.pumpAndSettle();
  }

  /// The reader saves its place after a pause; let it before unmounting.
  Future<void> leave(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 1));
    await unmountUi(tester);
  }

  testWidgets('waits for the painted page, then a page turn hides it', (
    tester,
  ) async {
    final app = await openBook(tester);
    expect(tip, findsNothing, reason: 'the page is still loading');

    await pagePainted(tester);
    expect(tip, findsOneWidget);
    final l10n = ReadflexLocalizations.of(tester.element(tip))!;
    expect(find.text(l10n.readerSelectionTipTitle), findsOneWidget);
    expect(app.preferencesService.current.readerSelectionTipShowCount, 1);

    // Opening on a position is not a page turn; turning one is.
    await tester.fling(
      find.byType(TextPagesView),
      const Offset(-300, 0),
      1000,
    );
    await waitForUi(
      tester,
      () => tip.evaluate().isEmpty,
      description: 'the tip hidden by a page turn',
    );
    await tester.pumpAndSettle();
    expect(app.preferencesService.current.readerSelectionTipDismissed, isFalse);
    expect(tester.takeException(), isNull);
    await leave(tester);
  });

  testWidgets('a text selection ends the tip for good', (tester) async {
    final app = await openBook(tester);
    await pagePainted(tester);
    expect(tip, findsOneWidget);

    tester
        .element(find.byType(TextPagesView))
        .read<ReaderSelectionCubit>()
        .select(text: 'weightless');
    await tester.pumpAndSettle();

    expect(tip, findsNothing);
    expect(app.preferencesService.current.readerSelectionTipDismissed, isTrue);
    await leave(tester);
  });

  testWidgets('a returning reader never sees it', (tester) async {
    final app = await openBook(tester, tipDismissed: true);
    await pagePainted(tester);

    expect(tip, findsNothing);
    expect(app.preferencesService.current.readerSelectionTipShowCount, 0);
    await leave(tester);
  });

  for (final profile in [
    VisualProfile.phone,
    VisualProfile.dark,
    VisualProfile.largeText,
  ]) {
    testWidgets('reader selection tip ${profile.name}', (tester) async {
      await openBook(tester, profile: profile);
      await pagePainted(tester);
      expect(tip, findsOneWidget);
      await expectUiGolden(tester, profile, 'reader-selection-tip');
      await leave(tester);
    }, tags: ['golden']);
  }
}
