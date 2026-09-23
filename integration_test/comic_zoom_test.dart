import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:reader_webview/reader_webview.dart';

import '../test/support/comic_fixture.dart';
import '../test/support/native_screenshots.dart';
import '../test/support/ui_test_app.dart';
import '../test/support/ui_test_driver.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('comic zoom renders in the native WebView without page changes', (
    tester,
  ) async {
    final app = await UiTestApp.create(withBook: false, nativeReader: true);
    addTearDown(app.dispose);
    final book = await addComicFixture(app);
    tester.platformDispatcher.defaultRouteNameTestValue = '/';
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
    await tester.pumpWidget(app.widget);
    await tapUi(tester, find.byKey(ValueKey('library-grid-${book.id}')));
    await waitForUi(
      tester,
      () =>
          find.byType(BookReaderWebView).evaluate().isNotEmpty &&
          tester
              .state<BookReaderWebViewState>(find.byType(BookReaderWebView))
              .debugIsReady,
      description: 'comic ready',
      timeout: const Duration(seconds: 45),
    );
    final controller = tester
        .state<BookReaderWebViewState>(find.byType(BookReaderWebView))
        .debugController!;
    await tester.pump(const Duration(milliseconds: 600));
    await controller.evaluateJavascript(
      source: '''
      window.comicState = () => {
        const r = reader.view.renderer;
        const doc = r.getContents().find(x => x.index === r.index).doc;
        const frame = doc.defaultView.frameElement;
        return {index:r.index, width:frame.getBoundingClientRect().width};
      };
      window.comicTap = () => {
        const r = reader.view.renderer;
        const doc = r.getContents().find(x => x.index === r.index).doc;
        const frame = doc.defaultView.frameElement;
        const rect = frame.getBoundingClientRect();
        doc.body.dispatchEvent(new MouseEvent('click', {bubbles:true,
          clientX:(innerWidth/2-rect.left)*frame.clientWidth/rect.width,
          clientY:(innerHeight/2-rect.top)*frame.clientHeight/rect.height}));
      };
      true;
    ''',
    );
    Future<void> tapComic() async {
      if (Platform.isIOS) {
        // Exercise the host adapter even when WebKit delivers no DOM touch.
        await tester.tapAt(tester.getCenter(find.byType(BookReaderWebView)));
      } else {
        await controller.evaluateJavascript(source: 'comicTap()');
      }
    }

    final before =
        await controller.evaluateJavascript(source: 'comicState()') as Map;
    expect(before['width'] as num, greaterThan(100));
    await tapComic();
    await tester.pump(const Duration(milliseconds: 80));
    await tapComic();
    await tester.pump(const Duration(milliseconds: 450));
    final zoomed =
        await controller.evaluateJavascript(source: 'comicState()') as Map;
    expect(zoomed['index'], before['index']);
    expect(zoomed['width'] as num, greaterThan((before['width'] as num) * 2));
    if (Platform.isAndroid) {
      await captureAndroidScreenshot('comic-zoomed');
    } else {
      await binding.takeScreenshot('comic-zoomed');
    }
    await tapComic();
    await tester.pump(const Duration(milliseconds: 80));
    await tapComic();
    await tester.pump(const Duration(milliseconds: 450));
    final reset =
        await controller.evaluateJavascript(source: 'comicState()') as Map;
    expect(reset['index'], before['index']);
    expect(reset['width'] as num, closeTo(before['width'] as num, 1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
