import 'dart:io';

import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vellum/all_formats.dart';

import '../test/support/native_screenshots.dart';
import '../test/support/ui_test_app.dart';
import '../test/support/ui_test_driver.dart';

/// A table wider than the page on vellum in the real app: as in the
/// WebView reader, it keeps every word whole and scrolls sideways in the
/// column; a swipe on it scrolls it, and once it is at its edge the swipe
/// turns the page.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a wide book table scrolls sideways', (tester) async {
    final app = await UiTestApp.create(withBook: false);
    addTearDown(app.dispose);
    const labels = [
      'Configuration',
      'Coordination',
      'Distribution',
      'Concurrency',
      'Communication',
      'Observability',
    ];
    final file = File('${app.directory.path}/table.fb2');
    await file.writeAsString('''<?xml version="1.0" encoding="utf-8"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0">
<description><title-info><book-title>Tables</book-title><lang>en</lang>
</title-info></description><body><section><title><p>Tables</p></title>
<table><tr>${labels.map((l) => '<td>$l</td>').join()}</tr></table>
${List.generate(40, (i) => '<p>Paragraph $i after the table keeps the book long enough to turn.</p>').join('\n')}
</section></body></FictionBook>''');
    final book = await app.bookRepository.addBook(
      sourceFile: file,
      title: 'Tables',
      format: BookFormat.fb2,
    );
    tester.platformDispatcher.defaultRouteNameTestValue = '/';
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
    await tester.pumpWidget(app.widget);
    await tapUi(tester, find.byKey(ValueKey('library-grid-${book.id}')));
    await waitForUi(
      tester,
      () => find.byType(TextColumnPage).evaluate().isNotEmpty,
      description: 'the first page',
      timeout: const Duration(seconds: 45),
    );
    await tester.pumpAndSettle();

    final page = tester.widget<TextColumnPage>(find.byType(TextColumnPage));
    final cells = [
      for (final label in labels)
        page.column.items.whereType<ColumnText>().firstWhere(
          (t) => t.paragraph.box.text == label,
        ),
    ];
    final scroller = page.column.scrollers.single;
    for (final cell in cells) {
      expect(cell.paragraph.lines, hasLength(1), reason: 'whole words');
      expect(cell.scroller, same(scroller));
    }
    expect(scroller.contentWidth, greaterThan(page.column.width));
    await _screenshot(binding, 'book-table');

    // A swipe on the table scrolls it; the page stays.
    final render = tester.renderObject<RenderTextColumnPage>(
      find.byType(TextColumnPage),
    );
    final onTable = render.localToGlobal(
      Offset(
        scroller.viewport.center.dx,
        scroller.viewport.center.dy - page.page.top,
      ),
    );
    await tester.dragFrom(onTable, const Offset(-150, 0));
    await tester.pumpAndSettle();
    expect(scroller.offset.value, greaterThan(50));
    expect(
      tester.widget<TextColumnPage>(find.byType(TextColumnPage)).page.top,
      page.page.top,
    );
    await _screenshot(binding, 'book-table-scrolled');

    // At its edge, a swipe on it turns the page.
    while (scroller.canScroll(1)) {
      await tester.dragFrom(onTable, const Offset(-200, 0));
      await tester.pumpAndSettle();
    }
    await tester.flingFrom(onTable, const Offset(-260, 0), 1500);
    await waitForUi(
      tester,
      () =>
          tester
              .widget<TextColumnPage>(find.byType(TextColumnPage).first)
              .page
              .top !=
          page.page.top,
      description: 'the next page',
    );
    // The reader saves its place after a pause.
    await tester.pump(const Duration(seconds: 1));
    await unmountUi(tester);
  });
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
