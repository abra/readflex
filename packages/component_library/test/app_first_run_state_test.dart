import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: child),
  );

  AppFirstRunState state({List<Widget>? actions, String? caption}) =>
      AppFirstRunState(
        iconFrameKey: const ValueKey('frame'),
        icon: AppIcons.book,
        title: 'Nothing yet',
        subtitle: 'Add something',
        actions:
            actions ??
            [
              FilledButton(
                key: const ValueKey('primary'),
                onPressed: () {},
                child: const Text('Start'),
              ),
              OutlinedButton(
                key: const ValueKey('secondary'),
                onPressed: () {},
                child: const Text('Other'),
              ),
            ],
        caption: caption,
      );

  testWidgets('a 72dp accent-tinted circle holds the glyph', (tester) async {
    await tester.pumpWidget(host(state()));

    final frame = find.byKey(const ValueKey('frame'));
    expect(tester.getSize(frame), const Size.square(72));
    final context = tester.element(frame);
    final decoration =
        tester.widget<Container>(frame).decoration! as BoxDecoration;
    expect(decoration.shape, BoxShape.circle);
    expect(decoration.color!.a, lessThan(.5));
    expect(decoration.color!.withValues(alpha: 1), context.actionForeground);
    final icon = tester.widget<Icon>(
      find.descendant(of: frame, matching: find.byIcon(AppIcons.book)),
    );
    expect(icon.color, context.actionForeground);
    expect(icon.size, AppIconSize.lg);
  });

  testWidgets('the title is the serif headlineSmall, the hint muted', (
    tester,
  ) async {
    await tester.pumpWidget(host(state()));
    final theme = AppTheme.light();

    final title = tester.widget<Text>(find.text('Nothing yet'));
    expect(title.style!.fontFamily, theme.textTheme.headlineSmall!.fontFamily);
    expect(title.style!.fontSize, theme.textTheme.headlineSmall!.fontSize);
    expect(title.textAlign, TextAlign.center);
    final hint = tester.widget<Text>(find.text('Add something'));
    expect(hint.style!.color, theme.colorScheme.onSurfaceVariant);
  });

  testWidgets('actions stretch to the gutter, 10dp apart, caption under', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(host(state(caption: 'Books and PDF')));

    final primary = tester.getRect(find.byKey(const ValueKey('primary')));
    final secondary = tester.getRect(find.byKey(const ValueKey('secondary')));
    expect(primary.left, AppSpacing.lg);
    expect(primary.right, 390 - AppSpacing.lg);
    expect(secondary.top - primary.bottom, AppSpacing.sm + AppSpacing.xxs);
    final caption = tester.getRect(find.text('Books and PDF'));
    expect(caption.top - secondary.bottom, AppSpacing.md);
  });

  testWidgets('a wide window keeps the column at 480dp', (tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(host(state()));

    final primary = tester.getRect(find.byKey(const ValueKey('primary')));
    expect(primary.width, AppSizes.centeredColumnMaxWidth);
    expect(primary.center.dx, closeTo(512, 0.01));
  });

  testWidgets('one action and no caption leave no stray gaps', (tester) async {
    await tester.pumpWidget(
      host(
        state(
          actions: [
            FilledButton(
              key: const ValueKey('primary'),
              onPressed: () {},
              child: const Text('Start'),
            ),
          ],
        ),
      ),
    );

    final hint = tester.getRect(find.text('Add something'));
    final primary = tester.getRect(find.byKey(const ValueKey('primary')));
    expect(primary.top - hint.bottom, AppSpacing.xl);
    expect(find.byType(OutlinedButton), findsNothing);
  });
}
