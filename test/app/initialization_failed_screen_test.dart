import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readflex/app/screens/initialization_failed_screen.dart';

void main() {
  Widget screen(Future<void> Function() retry) => InitializationFailedScreen(
    error: StateError('Initialization failed'),
    stackTrace: StackTrace.empty,
    onRetryInitialization: retry,
  );

  testWidgets('retry stays disabled until the attempt completes', (
    tester,
  ) async {
    final completion = Completer<void>();
    var attempts = 0;
    await tester.pumpWidget(
      screen(() {
        attempts++;
        return completion.future;
      }),
    );

    await tester.tap(find.byType(FilledButton));
    // A second tap can arrive before the disabled button has been rebuilt.
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(attempts, 1);
    completion.complete();
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('retry may complete after the recovery screen is removed', (
    tester,
  ) async {
    final completion = Completer<void>();
    await tester.pumpWidget(screen(() => completion.future));
    await tester.tap(find.byType(FilledButton));
    await tester.pumpWidget(const SizedBox.shrink());

    completion.complete();
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('a throwing retry reports its error and re-enables the button', (
    tester,
  ) async {
    final completion = Completer<void>();
    final error = StateError('Retry failed');
    await tester.pumpWidget(screen(() => completion.future));
    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    completion.completeError(error);
    await tester.pump();

    expect(tester.takeException(), same(error));
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });
}
