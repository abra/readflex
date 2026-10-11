import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:reader/src/reader_ui_cubit.dart';
import 'package:reader_webview/reader_webview.dart';

import '../test/support/native_screenshots.dart';
import '../test/support/pdf_fixture.dart';
import '../test/support/ui_test_app.dart';
import '../test/support/ui_test_driver.dart';

/// PDF pages in the native WebView: screen-density bitmaps, double-tap zoom
/// that ends sharp, theme colors with margin crops, and page previews.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'PDF pages zoom sharp and follow the theme in the native WebView',
    (
      tester,
    ) async {
      final app = await UiTestApp.create(withBook: false, nativeReader: true);
      addTearDown(app.dispose);
      final book = await addPdfFixture(app);
      tester.platformDispatcher.defaultRouteNameTestValue = '/';
      addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
      await tester.pumpWidget(app.widget);
      await tapUi(tester, find.byKey(ValueKey('library-grid-${book.id}')));
      BookReaderWebViewState reader() =>
          tester.state<BookReaderWebViewState>(find.byType(BookReaderWebView));
      await waitForUi(
        tester,
        () =>
            find.byType(BookReaderWebView).evaluate().isNotEmpty &&
            reader().debugIsReady,
        description: 'PDF ready',
        timeout: const Duration(seconds: 45),
      );
      final controller = reader().debugController!;
      await controller.evaluateJavascript(
        source: '''
      window.pdfState = () => {
        const r = reader.view.renderer;
        const doc = r.getContents().find(x => x.index === r.index)?.doc;
        const bitmap = doc?.querySelector('canvas.readflex-pdf-page');
        const tile = doc?.querySelector('canvas.readflex-pdf-tile');
        const frame = doc?.defaultView.frameElement;
        return {
          index: r.index,
          body: doc ? [...doc.body.children].map(e => e.getAttribute('class') || e.localName) : [],
          bitmap: bitmap?.width ?? 0,
          screen: innerWidth * devicePixelRatio,
          width: frame?.getBoundingClientRect().width ?? 0,
          tile: tile ? tile.width / parseFloat(tile.style.width) : 0,
          paper: bitmap ? [...bitmap.getContext('2d').getImageData(8, 8, 1, 1).data] : [],
          cropLeft: doc?.readflexVisibleRect?.left ?? 0,
        };
      };
      window.pdfTap = () => {
        const r = reader.view.renderer;
        const doc = r.getContents().find(x => x.index === r.index).doc;
        const frame = doc.defaultView.frameElement;
        const rect = frame.getBoundingClientRect();
        doc.body.dispatchEvent(new MouseEvent('click', {bubbles: true,
          clientX: (innerWidth / 2 - rect.left) * frame.clientWidth / rect.width,
          clientY: (innerHeight / 2 - rect.top) * frame.clientHeight / rect.height}));
      };
      true;
    ''',
      );
      Future<Map<Object?, Object?>> state() async =>
          await controller.evaluateJavascript(source: 'pdfState()') as Map;
      Future<void> waitFor(
        bool Function(Map<Object?, Object?> state) done,
        String description,
      ) async {
        final deadline = DateTime.now().add(const Duration(seconds: 10));
        while (true) {
          final current = await state();
          if (done(current)) return;
          if (DateTime.now().isAfter(deadline)) {
            fail('Timed out waiting for $description: $current');
          }
          await tester.pump(const Duration(milliseconds: 50));
        }
      }

      Future<void> tapCentre() async {
        if (Platform.isIOS) {
          // The host adapter carries both taps even if WebKit drops a touch.
          final box = tester.getRect(find.byType(BookReaderWebView));
          await tester.tapAt(box.center);
        } else {
          await controller.evaluateJavascript(source: 'pdfTap()');
        }
      }

      Future<void> doubleTap() async {
        await tapCentre();
        await tester.pump(const Duration(milliseconds: 80));
        await tapCentre();
        await tester.pump(const Duration(milliseconds: 450));
      }

      await waitFor((s) => (s['bitmap'] as num) > 0, 'first page bitmap');
      // Defaults: margins trimmed, paper in the Paper theme color.
      await waitFor(
        (s) =>
            (s['cropLeft'] as num) > 0 &&
            _sameColor(s['paper'] as List, const [250, 248, 244]),
        'trimmed page in theme colors',
      );
      final before = await state();
      expect(before['index'], 0);
      expect(before['body'], [
        'readflex-pdf-page',
        'textLayer',
        'annotationLayer',
        'svg',
      ]);
      // Trimmed pages render denser than the screen so the crop stays sharp.
      expect(
        before['bitmap'] as num,
        greaterThan((before['screen'] as num) * 1.25),
      );

      await doubleTap();
      await waitFor((s) => (s['tile'] as num) > 0, 'sharp tile');
      final zoomed = await state();
      expect(zoomed['index'], 0);
      expect(zoomed['width'] as num, greaterThan((before['width'] as num) * 2));
      expect(
        zoomed['tile'] as num,
        greaterThan((before['bitmap'] as num) / 1190 * 2),
        reason: 'the tile is denser than the page bitmap',
      );
      await _screenshot(binding, 'pdf-zoomed');

      await doubleTap();
      await waitFor((s) => s['tile'] == 0, 'tile dropped at page fit');

      await controller.evaluateJavascript(
        source:
            "changeStyle({pageColors: 'theme', backgroundColor: '#0F1115', "
            "fontColor: '#BCC1CA', cropPageMargins: true}); true;",
      );
      await waitFor(
        (s) =>
            _sameColor(s['paper'] as List, const [15, 17, 21]) &&
            (s['cropLeft'] as num) > 0,
        'dark theme and margin crop',
      );
      await _screenshot(binding, 'pdf-dark-cropped');

      // The real Appearance sheet turns both off for this book.
      final uiCubit = tester
          .element(find.byType(BookReaderWebView))
          .read<ReaderUiCubit>();
      final l10n = tester.element(find.byType(BookReaderWebView)).l10n;
      uiCubit.showChrome();
      await tester.pump(const Duration(milliseconds: 400));
      await tapUi(tester, find.byTooltip(l10n.readerAppearanceTitle));
      await tapUi(tester, find.text(l10n.readerPdfMarginsWhole));
      await tapUi(tester, find.text(l10n.readerPdfPageColorsOriginal));
      await waitFor(
        (s) =>
            (s['cropLeft'] as num) == 0 &&
            _sameColor(s['paper'] as List, const [255, 255, 255]),
        'whole page in original colors',
      );
      Navigator.of(tester.element(find.text(l10n.readerPdfMargins))).pop();
      await tester.pumpAndSettle();

      // Search and saved highlights run in WKWebView / Android WebView too.
      final found = await controller.callAsyncJavaScript(
        functionBody: '''
          let count = 0;
          for await (const result of reader.view.search({ query: 'Line 7 of page 3:' })) {
            if (result.subitems) count += result.subitems.length;
          }
          return count;
        ''',
      );
      expect(found?.value, 1, reason: 'PDF search finds the line');
      final drawn = await controller.callAsyncJavaScript(
        functionBody: '''
          const r = reader.view.renderer;
          const { doc, index } = r.getContents().find(x => x.index === r.index);
          const text = doc.querySelectorAll('.textLayer span')[2].firstChild;
          const range = doc.createRange();
          range.setStart(text, 0);
          range.setEnd(text, text.length);
          const cfi = reader.view.getCFI(index, range);
          window.addAnnotation({ id: 'native', value: cfi, cfi, type: 'highlight', color: '#ffe600' });
          await new Promise(resolve => setTimeout(resolve, 200));
          return doc.body.lastElementChild.querySelectorAll('rect').length;
        ''',
      );
      expect(drawn?.value, greaterThan(0), reason: 'the highlight is drawn');

      final preview = await reader().pageThumbnail(1);
      expect(preview, isNotNull);
      final codec = await ui.instantiateImageCodec(preview!);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 240);
      frame.image.dispose();
      codec.dispose();

      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

Future<void> _screenshot(
  IntegrationTestWidgetsFlutterBinding binding,
  String name,
) async {
  if (Platform.isAndroid) {
    await captureAndroidScreenshot(name);
  } else {
    await binding.takeScreenshot(name);
  }
}

bool _sameColor(List<Object?> pixel, List<int> expected) {
  if (pixel.length < expected.length) return false;
  for (var i = 0; i < expected.length; i++) {
    if (((pixel[i]! as num) - expected[i]).abs() > 2) return false;
  }
  return true;
}
