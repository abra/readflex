import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final height in [220.0, 400.0]) {
    testWidgets('constrained sheet keeps header and scrolls body at $height', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: 320,
                height: height,
                child: ActionBottomSheetLayout(
                  title: 'Appearance',
                  constrainBody: true,
                  headerTrailing: TextButton(
                    onPressed: () {},
                    child: const Text('Reset'),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (var i = 0; i < 30; i++)
                          SizedBox(height: 44, child: Text('Control $i')),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final headerTop = tester.getTopLeft(find.text('Appearance'));
      await tester.ensureVisible(find.text('Control 29'));
      await tester.pumpAndSettle();
      expect(find.text('Control 29').hitTestable(), findsOneWidget);
      expect(find.text('Reset').hitTestable(), findsOneWidget);
      expect(tester.getTopLeft(find.text('Appearance')), headerTop);
      expect(tester.takeException(), isNull);
    });
  }
}
