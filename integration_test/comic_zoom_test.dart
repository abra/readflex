import 'dart:io';

import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:reader/src/reader_page_grid.dart';
import 'package:reader/src/reader_ui_cubit.dart';
import 'package:vellum/all_formats.dart';

import '../test/support/comic_fixture.dart';
import '../test/support/native_screenshots.dart';
import '../test/support/ui_test_app.dart';
import '../test/support/ui_test_driver.dart';

/// A comic on vellum in the real app: double-tap zoom keeps the page, edge
/// taps turn pages and hide the chrome, and Contents previews the pages.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> screenshot(String name) async {
    if (Platform.isAndroid) {
      await captureAndroidScreenshot(name);
    } else {
      await binding.takeScreenshot(name);
    }
  }

  testWidgets('comic zoom keeps the page; edge taps turn it', (tester) async {
    final app = await UiTestApp.create(withBook: false);
    addTearDown(app.dispose);
    final book = await addComicFixture(app);
    tester.platformDispatcher.defaultRouteNameTestValue = '/';
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
    await tester.pumpWidget(app.widget);
    await tapUi(tester, find.byKey(ValueKey('library-grid-${book.id}')));
    await waitForFixedPage(tester);

    final pages = find.byType(FixedPagesView);
    FixedPagesController controller() =>
        tester.widget<FixedPagesView>(pages).controller;
    Future<void> tapComic({double x = 0.5}) async {
      final box = tester.getRect(pages);
      await tester.tapAt(Offset(box.left + box.width * x, box.center.dy));
    }

    Future<void> doubleTap() async {
      await tapComic();
      await tester.pump(const Duration(milliseconds: 80));
      await tapComic();
      await tester.pump(const Duration(milliseconds: 450));
    }

    Future<void> waitForPage(int index) => waitForUi(
      tester,
      () => controller().page == index,
      description: 'comic page $index',
    );

    expect(
      controller().page,
      0,
      reason: 'Opening must not skip the first page',
    );
    await doubleTap();
    await waitForUi(
      tester,
      () => controller().isZoomed,
      description: 'zoomed page',
    );
    expect(controller().page, 0);
    expect(controller().zoomScale, greaterThan(2));
    await screenshot('comic-zoomed');
    await doubleTap();
    await waitForUi(
      tester,
      () => !controller().isZoomed,
      description: 'page fit',
    );
    expect(controller().page, 0);

    final uiCubit = tester.element(pages).read<ReaderUiCubit>();
    await tapComic();
    await tester.pump(const Duration(milliseconds: 450));
    expect(uiCubit.state.chromeVisible, isTrue);
    // Stay in the page zone, outside the visible brightness control's hit box.
    await tapComic(x: 0.8);
    await waitForPage(1);
    expect(uiCubit.state.chromeVisible, isFalse);
    await tapComic(x: 0.8);
    await waitForPage(2);
    await tapComic(x: 0.1);
    await waitForPage(1);
    await tester.pump(const Duration(milliseconds: 250));
    await screenshot('comic-after-edge-turns');
    expect(tester.takeException(), isNull);

    uiCubit.showChrome();
    await tester.pump(const Duration(milliseconds: 350));
    await tapUi(tester, find.byIcon(AppIcons.toc));
    await waitForUi(
      tester,
      () => find.byType(ReaderPageGrid).evaluate().isNotEmpty,
      description: 'comic Pages tab',
    );
    final previews = find.descendant(
      of: find.byType(ReaderPageGrid),
      matching: find.byType(RawImage),
    );
    await waitForUi(
      tester,
      () =>
          previews
              .evaluate()
              .where((e) => (e.widget as RawImage).image != null)
              .length >=
          2,
      description: 'page previews',
    );
    await screenshot('comic-pages');
    await tester.ensureVisible(find.text('Page 3'));
    await tester.pump(const Duration(milliseconds: 350));
    await tapUi(tester, find.text('Page 3'));
    await waitForPage(2);
    expect(uiCubit.state.tocDrawerVisible, isFalse);
    // The reader saves its place after a pause.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
