import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
