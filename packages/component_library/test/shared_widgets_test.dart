import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ActionBottomSheetLayout renders title and child', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ActionBottomSheetLayout(
            title: 'Sheet',
            onClose: _noop,
            child: Text('Body'),
          ),
        ),
      ),
    );

    expect(find.text('Sheet'), findsOneWidget);
    expect(find.text('Body'), findsOneWidget);
  });

  testWidgets('SelectionPreviewCard renders selected text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SelectionPreviewCard(text: 'Selected text'),
        ),
      ),
    );

    expect(find.text('Selected text'), findsOneWidget);
  });

  testWidgets('DestructiveDismissBackground shows delete icon', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DestructiveDismissBackground(),
        ),
      ),
    );

    expect(find.byIcon(Icons.delete), findsOneWidget);
  });

  testWidgets('ButtonLoadingIndicator renders progress indicator', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ButtonLoadingIndicator(),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}

void _noop() {}
