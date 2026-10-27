import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:practice/practice.dart';
import 'package:reader/reader.dart';
import 'package:readflex/app/routing.dart';

import '../support/reader_test_platform.dart';
import '../support/ui_test_app.dart';
import '../support/ui_test_driver.dart';

/// Open in book from a saved word opens the reader at the word's anchor:
/// the route carries `initialCfi`, the reader applies it once the document
/// is ready, and leaving the reader lands back on the Vocabulary list.
void main() {
  late UiTestApp app;
  late ReaderTestPlatform platform;

  setUp(() async {
    app = await UiTestApp.create();
    await app.readerServer.start();
    final previous = InAppWebViewPlatform.instance;
    platform = ReaderTestPlatform();
    InAppWebViewPlatform.instance = platform;
    addTearDown(() {
      if (previous != null) InAppWebViewPlatform.instance = previous;
    });
  });
  tearDown(() async => app.dispose());

  const anchor = 'epubcfi(/6/2!/4/2,/1:0,/1:5)';

  testWidgets('a saved word opens its book at the anchor', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final entry = await tester.runAsync(
      () => app.dictionaryRepository.addEntry(
        word: 'power',
        translation: 'Strom',
        sourceId: app.book!.id,
        sourceType: SourceType.book,
        anchorText: 'power',
        anchorCfiRange: anchor,
      ),
    );

    await tester.pumpWidget(app.widgetAt(AppRoutes.practiceWords));
    final word = find.byKey(ValueKey('practiceWord-${entry!.id}'));
    await tapUi(tester, word);
    await tapUi(tester, find.text('Open in book'));
    await waitForUi(
      tester,
      () => platform.views.any(
        (view) =>
            view.created && view.controller.handlers.containsKey('onLoadEnd'),
      ),
      description: 'WebView bridge',
    );
    final controller = platform.views
        .firstWhere((view) => view.created)
        .controller;
    expect(
      controller.scripts.any((script) => script.contains('goToCfi(')),
      isFalse,
      reason: 'the anchor waits for the document',
    );
    controller.handlers['onLoadEnd']!([]);
    await waitForUi(
      tester,
      () => controller.scripts.any(
        (script) => script.contains('goToCfi("$anchor")'),
      ),
      description: 'reader at the word anchor',
    );
    expect(find.byType(ReaderScreen), findsOneWidget);

    // Leaving the reader lands on the Vocabulary list it was opened from.
    GoRouter.of(tester.element(find.byType(ReaderScreen))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(ReaderScreen), findsNothing);
    expect(find.byType(PracticeWordsScreen), findsOneWidget);
    await unmountUi(tester);
  });
}
