import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required ThemeData theme,
    double height = 56,
    Widget child = const SizedBox(width: 120),
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Center(
            child: AppFloatingCapsule(
              key: const ValueKey('capsule'),
              height: height,
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration decoration(WidgetTester tester) =>
      tester
              .widget<DecoratedBox>(
                find.descendant(
                  of: find.byKey(const ValueKey('capsule')),
                  matching: find.byType(DecoratedBox),
                ),
              )
              .decoration
          as BoxDecoration;

  for (final dark in [false, true]) {
    testWidgets('translucent surface, hairline outline and popover shadow '
        'dark=$dark', (tester) async {
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetDevicePixelRatio);
      final theme = dark ? AppTheme.dark() : AppTheme.light();
      await pump(tester, theme: theme);
      final colors = theme.colorScheme;
      final box = decoration(tester);
      expect(
        box.color,
        colors.surface.withValues(alpha: kAppFloatingCapsuleOpacity),
      );
      expect(box.boxShadow, AppShadows.popover);
      final border = box.border! as Border;
      expect(border.top.color, colors.outlineVariant);
      expect(border.top.width, 1 / 3);
      expect(border.isUniform, isTrue);
    });
  }

  testWidgets('takes the given height, a matching stadium radius and hugs '
      'its child', (tester) async {
    await pump(tester, theme: AppTheme.light(), height: 60);
    final size = tester.getSize(find.byKey(const ValueKey('capsule')));
    expect(size, const Size(120, 60));
    expect(decoration(tester).borderRadius, BorderRadius.circular(30));
  });

  testWidgets('keeps the controls interactive and inked by themselves', (
    tester,
  ) async {
    var taps = 0;
    await pump(
      tester,
      theme: AppTheme.light(),
      child: AppPlainIconButton(
        icon: AppIcons.add,
        tooltip: 'Add',
        onPressed: () => taps++,
      ),
    );
    await tester.tap(find.byTooltip('Add'));
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });
}
