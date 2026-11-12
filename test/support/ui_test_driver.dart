import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagecraft/pagecraft.dart' show FixedPagePainter;
import 'package:pagecraft/src/formats/pdf/pdf_native_task.dart';

/// Bounded condition wait, including real SQLite/platform work outside the
/// widget test's fake clock. Avoid pumpAndSettle while a spinner is active.
Future<void> waitForUi(
  WidgetTester tester,
  bool Function() ready, {
  required String description,
  Duration timeout = const Duration(seconds: 15),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!ready()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for $description');
    }
    await tester.runAsync(
      () => Future<void>.delayed(
        const Duration(milliseconds: 30),
      ),
    );
    await tester.pump(const Duration(milliseconds: 30));
    expect(tester.takeException(), isNull, reason: description);
  }
  await tester.pump();
}

/// Waits until a fixed-layout page (comic, PDF) paints its image: the
/// engine decodes it off the fake clock.
Future<void> waitForFixedPage(WidgetTester tester) => waitForUi(
  tester,
  () => find
      .byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter is FixedPagePainter,
      )
      .evaluate()
      .isNotEmpty,
  description: 'a painted page',
  timeout: const Duration(seconds: 30),
);

Future<void> tapUi(WidgetTester tester, Finder target) async {
  await waitForUi(
    tester,
    () => target.hitTestable().evaluate().isNotEmpty,
    description: 'tappable $target',
  );
  await tester.tap(target.hitTestable().first);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  expect(tester.takeException(), isNull);
}

Future<void> dismissSheet(WidgetTester tester) async {
  expect(find.byType(ModalBarrier), findsWidgets);
  await tester.tapAt(const Offset(12, 24));
  await tester.pumpAndSettle();
}

Future<void> unmountUi(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  var drained = false;
  unawaited(runPdfDocumentTask(() async {}).then((_) => drained = true));
  await tester.pump();
  // Finish native close callbacks before leaving this test's fake-clock zone.
  await waitForUi(
    tester,
    () => drained,
    description: 'PDF document cleanup',
  );
}
