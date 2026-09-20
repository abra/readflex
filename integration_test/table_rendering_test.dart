import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:reader_webview/reader_webview.dart';

import '../test/support/native_screenshots.dart';
import '../test/support/reading_fixture.dart';
import '../test/support/ui_test_app.dart';
import '../test/support/ui_test_driver.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('wide book tables scroll without moving the reading page', (
    tester,
  ) async {
    final app = await UiTestApp.create(nativeReader: true);
    addTearDown(app.dispose);
    // EPUB parsing is covered in browsers; isolate native table painting,
    // scrolling and CFI behavior in the production renderer here.
    const table = '''<table id="wide-table"><tr>
<td id="table-label">Configuration</td><td>Coordination</td>
<td>Distribution</td><td>Concurrency</td>
<td>Communication</td><td id="last-label">Observability</td>
</tr></table>''';
    tester.platformDispatcher.defaultRouteNameTestValue = '/';
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
    await tester.pumpWidget(app.widget);
    await tapUi(tester, find.byKey(ValueKey('library-grid-${app.book!.id}')));
    await waitForUi(
      tester,
      () {
        final element = find.byType(BookReaderWebView).evaluate().firstOrNull;
        return element != null &&
            tester
                .state<BookReaderWebViewState>(find.byType(BookReaderWebView))
                .debugIsReady;
      },
      description: 'book ready',
      timeout: const Duration(seconds: 45),
    );
    final controller = tester
        .state<BookReaderWebViewState>(find.byType(BookReaderWebView))
        .debugController!;

    Future<void> waitForDom(String condition) async {
      final deadline = DateTime.now().add(const Duration(seconds: 15));
      while (await controller.evaluateJavascript(source: condition) != true) {
        if (DateTime.now().isAfter(deadline)) fail(condition);
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Future<void> capture(String name, String labelId) async {
      if (Platform.isAndroid) {
        await captureAndroidScreenshot(name);
        return;
      }
      final bounds =
          await controller.evaluateJavascript(
                source:
                    '''(() => {
          const {doc} = window.reader.view.renderer.getContents()[0];
          const range = doc.createRange();
          range.selectNodeContents(doc.getElementById(${jsonEncode(labelId)}));
          const text = range.getBoundingClientRect();
          const frame = doc.defaultView.frameElement.getBoundingClientRect();
          return {x: frame.x + text.x, y: frame.y + text.y,
            width: text.width, height: text.height};
        })()''',
              )
              as Map;
      final webView = tester.getRect(find.byType(BookReaderWebView));
      final bytes = await binding
          .takeScreenshot(name)
          .timeout(const Duration(seconds: 20));
      final codec = await ui.instantiateImageCodec(Uint8List.fromList(bytes));
      final frame = await codec.getNextFrame();
      try {
        final pixels = (await frame.image.toByteData())!;
        final logicalSize =
            tester.view.physicalSize / tester.view.devicePixelRatio;
        final scale = frame.image.width / logicalSize.width;
        final rect = Rect.fromLTWH(
          webView.left + (bounds['x'] as num).toDouble(),
          webView.top + (bounds['y'] as num).toDouble(),
          (bounds['width'] as num).toDouble(),
          (bounds['height'] as num).toDouble(),
        ).intersect(webView);
        expect(rect.isEmpty, isFalse, reason: 'Table label must be in view');
        var ink = 0;
        for (
          var y = (rect.top * scale).ceil();
          y < (rect.bottom * scale).floor();
          y++
        ) {
          for (
            var x = (rect.left * scale).ceil();
            x < (rect.right * scale).floor();
            x++
          ) {
            final offset = (y * frame.image.width + x) * 4;
            if (pixels.getUint8(offset) < 130 &&
                pixels.getUint8(offset + 1) < 130 &&
                pixels.getUint8(offset + 2) < 130) {
              ink++;
            }
          }
        }
        expect(
          ink,
          greaterThan(20),
          reason: 'Geometry alone cannot detect a blank table',
        );
      } finally {
        frame.image.dispose();
        codec.dispose();
      }
    }

    await waitForDom(
      '(window.reader?.view?.renderer?.getContents?.() ?? [])'
      '.some(({doc}) => doc.body?.textContent.includes(${jsonEncode(ReadingFixture.phrase)}))',
    );
    await tester.pump(const Duration(milliseconds: 350));
    await controller.evaluateJavascript(
      source:
          '''void (async () => {
      const {doc} = window.reader.view.renderer.getContents()[0];
      const {normalizeLoadedDocument} = await import('./src/readflex_document_normalizer.js');
      doc.body.innerHTML = '<p>Paragraphs before a table in a later book page.</p>'.repeat(60)
        + ${jsonEncode(table)} + '<p>After the table.</p>';
      normalizeLoadedDocument(doc);
      window.tableTestReady = true;
    })();''',
    );
    await waitForDom('window.tableTestReady === true');
    for (final mode in ['slide', 'vertical', 'scroll']) {
      await controller.evaluateJavascript(
        source: 'window.changeStyle({pageTurnStyle: ${jsonEncode(mode)}});',
      );
      await tester.pump(const Duration(milliseconds: 350));
      await controller.evaluateJavascript(
        source: '''(() => {
        const {doc, index} = window.reader.view.renderer.getContents()[0];
        doc.getElementById('wide-table').parentElement.scrollLeft = 0;
        const range = doc.createRange();
        range.selectNodeContents(doc.getElementById('table-label'));
        window.reader.view.goTo(window.reader.view.getCFI(index, range));
      })();''',
      );
      await tester.pump(const Duration(milliseconds: 500));
      final before =
          await controller.evaluateJavascript(
                source: '''(() => {
        const {doc, index} = window.reader.view.renderer.getContents()[0];
        const wrapper = doc.getElementById('wide-table').parentElement;
        const range = doc.createRange();
        range.selectNodeContents(doc.getElementById('table-label'));
        window.tableTestCfi = window.reader.view.getCFI(index, range);
        window.tableTestLocation = window.reader.view.lastLocation.cfi;
        return {lines: range.getClientRects().length,
          overflow: doc.defaultView.getComputedStyle(wrapper).overflowX,
          wide: wrapper.scrollWidth > wrapper.clientWidth + 4};
      })();''',
              )
              as Map;
      expect(before['lines'], 1);
      expect(before['overflow'], 'auto');
      expect(before['wide'], true);
      await capture('book-table-$mode-start', 'table-label');
      await controller.evaluateJavascript(
        source: '''(() => {
        const {doc} = window.reader.view.renderer.getContents()[0];
        const wrapper = doc.getElementById('wide-table').parentElement;
        wrapper.scrollLeft = wrapper.scrollWidth - wrapper.clientWidth;
      })();''',
      );
      await tester.pump(const Duration(milliseconds: 150));
      final after =
          await controller.evaluateJavascript(
                source: '''(() => {
        const {doc, index} = window.reader.view.renderer.getContents()[0];
        const range = doc.createRange();
        range.selectNodeContents(doc.getElementById('table-label'));
        return {scrolled: doc.getElementById('wide-table').parentElement.scrollLeft > 0,
          sameCfi: window.reader.view.getCFI(index, range) === window.tableTestCfi,
          samePage: window.reader.view.lastLocation.cfi === window.tableTestLocation};
      })();''',
              )
              as Map;
      expect(after, {'scrolled': true, 'sameCfi': true, 'samePage': true});
      await capture('book-table-$mode-end', 'last-label');
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
