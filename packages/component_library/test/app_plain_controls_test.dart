import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('plain icon actions have round ink and a labeled 48dp target', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Center(
              child: AppPlainIconButton(
                icon: AppIcons.close,
                tooltip: 'Close',
                onPressed: () => calls++,
              ),
            ),
          ),
        ),
      );
      final button = find.byType(IconButton);
      final style = tester.widget<IconButton>(button).style!;
      expect(style.shape!.resolve({}), isA<CircleBorder>());
      expect(style.backgroundColor!.resolve({}), Colors.transparent);
      expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
      expect(tester.getSize(button).width, greaterThanOrEqualTo(48));
      await tester.tapAt(tester.getTopLeft(button) + const Offset(5, 5));
      expect(calls, 1);
      expect(tester, meetsGuideline(androidTapTargetGuideline));
      expect(tester, meetsGuideline(labeledTapTargetGuideline));
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('filter exposes one named action including its tap padding', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Center(
              child: AppFilterChip(
                label: 'Books',
                count: 3,
                selected: true,
                onTap: () => calls++,
              ),
            ),
          ),
        ),
      );
      expect(find.bySemanticsLabel('Books, 3'), findsOneWidget);
      expect(tester, meetsGuideline(androidTapTargetGuideline));
      expect(tester, meetsGuideline(labeledTapTargetGuideline));
      final chip = find.byType(AppFilterChip);
      await tester.tapAt(
        tester.getTopLeft(chip) + Offset(tester.getSize(chip).width / 2, 2),
      );
      await tester.tap(chip);
      expect(calls, 2);
    } finally {
      semantics.dispose();
    }
  });
}
