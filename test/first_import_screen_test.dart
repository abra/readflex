import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readflex/app/first_import_screen.dart';

void main() {
  Widget buildSubject({
    required Future<bool> Function() onAddPressed,
    required VoidCallback onContentAdded,
    VoidCallback? onSkipPressed,
  }) {
    return MaterialApp(
      home: FirstImportScreen(
        onAddPressed: onAddPressed,
        onContentAdded: onContentAdded,
        onSkipPressed: onSkipPressed ?? () {},
      ),
    );
  }

  testWidgets('calls onAddPressed when Add is tapped', (tester) async {
    var addPressedCount = 0;

    await tester.pumpWidget(
      buildSubject(
        onAddPressed: () async {
          addPressedCount += 1;
          return false;
        },
        onContentAdded: () {},
      ),
    );

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(addPressedCount, 1);
  });

  testWidgets('calls onContentAdded when add flow reports success', (
    tester,
  ) async {
    var contentAddedCount = 0;

    await tester.pumpWidget(
      buildSubject(
        onAddPressed: () async => true,
        onContentAdded: () {
          contentAddedCount += 1;
        },
      ),
    );

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(contentAddedCount, 1);
  });

  testWidgets('does not call onContentAdded when add flow reports failure', (
    tester,
  ) async {
    var contentAddedCount = 0;

    await tester.pumpWidget(
      buildSubject(
        onAddPressed: () async => false,
        onContentAdded: () {
          contentAddedCount += 1;
        },
      ),
    );

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(contentAddedCount, 0);
  });

  testWidgets('calls onSkipPressed when Skip is tapped', (tester) async {
    var skipPressedCount = 0;

    await tester.pumpWidget(
      buildSubject(
        onAddPressed: () async => false,
        onContentAdded: () {},
        onSkipPressed: () {
          skipPressedCount += 1;
        },
      ),
    );

    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();

    expect(skipPressedCount, 1);
  });

  testWidgets('disables repeated taps while add flow is in progress', (
    tester,
  ) async {
    var addPressedCount = 0;
    final completer = Completer<bool>();

    await tester.pumpWidget(
      buildSubject(
        onAddPressed: () {
          addPressedCount += 1;
          return completer.future;
        },
        onContentAdded: () {},
      ),
    );

    await tester.tap(find.text('Add'));
    await tester.pump();
    await tester.tap(find.text('Opening...'));
    await tester.pump();

    expect(addPressedCount, 1);

    completer.complete(false);
    await tester.pumpAndSettle();
  });
}
