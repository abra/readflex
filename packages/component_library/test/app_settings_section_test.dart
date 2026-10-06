import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required TextDirection direction,
    EdgeInsetsGeometry titlePadding = EdgeInsets.zero,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Directionality(
          textDirection: direction,
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: AppSettingsSection(
                title: 'Theme',
                titlePadding: titlePadding,
                child: const SizedBox(
                  key: ValueKey('child'),
                  height: 40,
                  width: double.infinity,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('title is a header with an 8dp gap to the child', (tester) async {
    await pump(tester, direction: TextDirection.ltr);
    expect(
      tester.getSemantics(find.text('Theme')).flagsCollection.isHeader,
      isTrue,
    );
    final title = tester.getRect(find.text('Theme'));
    final child = tester.getRect(find.byKey(const ValueKey('child')));
    expect(child.top - title.bottom, AppSpacing.sm);
    expect(title.left, 20);
    expect(child.left, 20);
  });

  for (final direction in TextDirection.values) {
    testWidgets('titlePadding insets only the title ($direction)', (
      tester,
    ) async {
      await pump(
        tester,
        direction: direction,
        titlePadding: const EdgeInsetsDirectional.only(start: 4),
      );
      final title = tester.getRect(find.text('Theme'));
      final child = tester.getRect(find.byKey(const ValueKey('child')));
      final width = tester.getSize(find.byType(Scaffold)).width;
      if (direction == TextDirection.ltr) {
        expect(title.left, 24);
        expect(child.left, 20);
      } else {
        expect(width - title.right, 24);
        expect(width - child.right, 20);
      }
    });
  }
}
