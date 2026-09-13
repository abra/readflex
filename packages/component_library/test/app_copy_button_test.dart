import 'dart:async';

import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget subject(Future<void> Function() onCopy) => MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: AppCopyButton(
        onCopy: onCopy,
        copyLabel: 'Copy',
        copiedLabel: 'Copied',
        failureLabel: 'Could not copy',
      ),
    ),
  );

  testWidgets(
    'copy has a 48px target and reports success only after completion',
    (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        final pending = Completer<void>();
        var calls = 0;
        await tester.pumpWidget(
          subject(() {
            calls++;
            return pending.future;
          }),
        );
        final button = find.byType(IconButton);
        expect(tester.getSize(button), const Size(48, 48));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await tester.tapAt(tester.getTopLeft(button) + const Offset(1, 1));
        await tester.pump();
        await tester.tap(button);
        expect(calls, 1);
        expect(find.byIcon(AppIcons.check), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        pending.complete();
        await tester.pumpAndSettle();
        expect(find.byTooltip('Copied'), findsOneWidget);
        expect(find.byIcon(AppIcons.check), findsOneWidget);
        await tester.pump(const Duration(seconds: 2));
        expect(find.byTooltip('Copy'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('failed copy remains retryable and late completion is safe', (
    tester,
  ) async {
    final pending = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      subject(() async {
        if (++calls == 1) throw StateError('clipboard unavailable');
        return pending.future;
      }),
    );
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Could not copy'), findsOneWidget);
    expect(find.byIcon(AppIcons.check), findsNothing);
    await tester.tap(find.byType(IconButton));
    await tester.pumpWidget(const SizedBox.shrink());
    pending.complete();
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(tester.takeException(), isNull);
  });
}
