import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final height in [80.0, 900.0]) {
    testWidgets('scrollable shell fits content and pins context: $height', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: 390,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 400),
                  child: ActionBottomSheetLayout.scrollable(
                    title: 'Translation',
                    headerBottom: const SizedBox(
                      key: ValueKey('direction'),
                      height: 48,
                    ),
                    child: SizedBox(
                      key: const ValueKey('body'),
                      height: height,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final sheet = tester.getRect(find.byType(ActionBottomSheetLayout));
      final fades = tester.getRect(find.byType(ScrollEdgeFadeStack));
      final body = tester.getRect(find.byKey(const ValueKey('body')));
      expect(fades.left, sheet.left);
      expect(fades.right, sheet.right);
      expect(body.left, sheet.left + 24);
      expect(body.right, sheet.right - 24);
      final header = tester.getRect(find.byType(BottomSheetHeader));
      final direction = tester.getRect(find.byKey(const ValueKey('direction')));
      final scroll = tester.state<ScrollableState>(find.byType(Scrollable));
      expect(scroll.position.maxScrollExtent > 0, height == 900);
      expect(sheet.height, height == 80 ? 208 : 400);
      scroll.position.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(BottomSheetHeader)), header);
      expect(
        tester.getRect(find.byKey(const ValueKey('direction'))),
        direction,
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final bodyHeight in [80.0, 180.0, 600.0]) {
    testWidgets('footer stays pinned with body height $bodyHeight', (
      tester,
    ) async {
      const sheetKey = ValueKey('sheet');
      const footerKey = ValueKey('footer');
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: 390,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: 272,
                    maxHeight: 500,
                  ),
                  child: ActionBottomSheetLayout(
                    key: sheetKey,
                    title: 'Consent',
                    constrainBody: true,
                    bodyPadding: const EdgeInsets.symmetric(horizontal: 24),
                    footer: const SizedBox(key: footerKey, height: 48),
                    child: SingleChildScrollView(
                      child: SizedBox(height: bodyHeight),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final sheetRect = tester.getRect(find.byKey(sheetKey));
      final footerRect = tester.getRect(find.byKey(footerKey));
      const chromeHeight = 48 + 8 + 8 + 48 + 16;
      expect(sheetRect.height, (chromeHeight + bodyHeight).clamp(272, 500));
      expect(footerRect.bottom, sheetRect.bottom - AppSpacing.lg);
      expect(
        tester.getTopLeft(find.byType(BottomSheetHeader)).dy,
        sheetRect.top,
      );
      final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
      expect(scrollable.position.maxScrollExtent > 0, bodyHeight == 600);
      if (scrollable.position.maxScrollExtent > 0) {
        scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
        await tester.pump();
        expect(tester.getRect(find.byKey(footerKey)), footerRect);
        expect(
          tester.getTopLeft(find.byType(BottomSheetHeader)).dy,
          sheetRect.top,
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

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
