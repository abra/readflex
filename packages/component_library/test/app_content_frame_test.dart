import 'package:component_library/component_library.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('wide workspace bounds an Expanded lazy list', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppContentFrame(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              key: const ValueKey('workspace'),
              children: [
                const SizedBox(
                  height: AppSizes.buttonHeight,
                  child: Text('Library'),
                ),
                Expanded(
                  child: ListView.builder(
                    itemExtent: AppSizes.buttonHeight,
                    itemCount: 1000,
                    itemBuilder: (_, index) => Text('Book $index'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final bounds = tester.getRect(find.byKey(const ValueKey('workspace')));
    expect(bounds.width, AppSizes.pageContentMaxWidth);
    expect(bounds.center.dx, 720);
    expect(bounds.top, AppSpacing.xl);
    expect(bounds.bottom, 900 - AppSpacing.xl);
    expect(find.text('Book 999'), findsNothing);
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.text('Book 0'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a narrow RTL workspace retains its directional gutter', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: AppContentFrame(
              padding: const EdgeInsetsDirectional.only(
                start: AppSpacing.xl,
                end: AppSpacing.lg,
              ),
              child: const SizedBox(key: ValueKey('workspace'), height: 100),
            ),
          ),
        ),
      ),
    );

    final bounds = tester.getRect(find.byKey(const ValueKey('workspace')));
    expect(bounds.left, AppSpacing.lg);
    expect(bounds.right, 320 - AppSpacing.xl);
    expect(tester.takeException(), isNull);
  });
}
