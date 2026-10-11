import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:reader/reader.dart';
import 'package:reader/src/reader_selection_cubit.dart';
import 'package:reader/src/reader_selection_tip.dart';
import 'package:reader_webview/reader_webview.dart';

import '../support/reader_test_platform.dart';
import '../support/ui_test_app.dart';
import '../support/ui_test_driver.dart';
import 'golden_support.dart';

/// The one-time "Press and hold a word" tip in the real reader: it waits for
/// the painted page, a page turn hides it for the session, a selection ends
/// it for good, and a returning reader never sees it.
void main() {
  setUpAll(loadUiFonts);

  final tip = find.byType(ReaderSelectionTipCard);

  Future<
    ({UiTestApp app, Map<String, dynamic Function(List<dynamic>)> handlers})
  >
  openBook(
    WidgetTester tester, {
    VisualProfile profile = VisualProfile.phone,
    bool tipDismissed = false,
  }) async {
    final app = (await tester.runAsync(
      () => UiTestApp.create(readerSelectionTipDismissed: tipDismissed),
    ))!;
    addTearDown(app.dispose);
    final previous = InAppWebViewPlatform.instance;
    final platform = ReaderTestPlatform();
    InAppWebViewPlatform.instance = platform;
    addTearDown(() {
      if (previous != null) InAppWebViewPlatform.instance = previous;
    });

    await pumpGoldenSurface(
      tester,
      profile,
      (_) => ReaderScreen(
        sourceId: app.book!.id,
        serverBaseUri: Uri.parse('http://127.0.0.1:49152'),
        bookRepository: app.bookRepository,
        highlightRepository: app.highlightRepository,
        preferencesService: app.preferencesService,
        screenControlService: app.screenControlService,
        textActions: const [],
        initialSource: app.book,
      ),
    );
    await waitForUi(
      tester,
      () => platform.views.any(
        (view) =>
            view.created && view.controller.handlers.containsKey('onLoadEnd'),
      ),
      description: 'WebView bridge',
    );
    final handlers = platform.views
        .firstWhere((view) => view.created)
        .controller
        .handlers;
    return (app: app, handlers: handlers);
  }

  testWidgets('waits for the painted page, then a page turn hides it', (
    tester,
  ) async {
    final (:app, :handlers) = await openBook(tester);
    expect(tip, findsNothing, reason: 'the page is still loading');

    handlers['onLoadEnd']!([]);
    await tester.pumpAndSettle();
    expect(tip, findsOneWidget);
    final l10n = ReadflexLocalizations.of(tester.element(tip))!;
    expect(find.text(l10n.readerSelectionTipTitle), findsOneWidget);
    expect(app.preferencesService.current.readerSelectionTipShowCount, 1);

    // Restoring a position is not a page turn; turning one is.
    handlers['onRelocated']!([
      {'cfi': 'epubcfi(/6/2!/4/2/1:0)', 'percentage': 0, 'reason': 'anchor'},
    ]);
    await tester.pumpAndSettle();
    expect(tip, findsOneWidget);

    handlers['onRelocated']!([
      {'cfi': 'epubcfi(/6/4!/4/2/1:0)', 'percentage': 0.1, 'reason': 'page'},
    ]);
    await tester.pumpAndSettle();
    expect(tip, findsNothing);
    expect(app.preferencesService.current.readerSelectionTipDismissed, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a text selection ends the tip for good', (tester) async {
    final (:app, :handlers) = await openBook(tester);
    handlers['onLoadEnd']!([]);
    await tester.pumpAndSettle();
    expect(tip, findsOneWidget);

    tester
        .element(find.byType(BookReaderWebView))
        .read<ReaderSelectionCubit>()
        .select(text: 'weightless');
    await tester.pumpAndSettle();

    expect(tip, findsNothing);
    expect(app.preferencesService.current.readerSelectionTipDismissed, isTrue);
  });

  testWidgets('a returning reader never sees it', (tester) async {
    final (:app, :handlers) = await openBook(tester, tipDismissed: true);
    handlers['onLoadEnd']!([]);
    await tester.pumpAndSettle();

    expect(tip, findsNothing);
    expect(app.preferencesService.current.readerSelectionTipShowCount, 0);
  });

  for (final profile in [
    VisualProfile.phone,
    VisualProfile.dark,
    VisualProfile.largeText,
  ]) {
    testWidgets('reader selection tip ${profile.name}', (tester) async {
      final (app: _, :handlers) = await openBook(tester, profile: profile);
      handlers['onLoadEnd']!([]);
      await tester.pumpAndSettle();
      expect(tip, findsOneWidget);
      await expectUiGolden(tester, profile, 'reader-selection-tip');
    }, tags: ['golden']);
  }
}
