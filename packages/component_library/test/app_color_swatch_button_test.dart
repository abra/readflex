import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child, {bool reduceMotion = false}) => MaterialApp(
    theme: AppTheme.light(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: child!,
    ),
    home: Scaffold(body: Center(child: child)),
  );

  AnimatedContainer circle(WidgetTester tester) =>
      tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));

  testWidgets('has a 48dp circular-ink target around a 32dp sample', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      var calls = 0;
      await tester.pumpWidget(
        host(
          AppColorSwatchButton(
            color: const Color(0xFFFFE066),
            selected: false,
            tooltip: 'Yellow',
            onPressed: () => calls++,
          ),
        ),
      );
      final target = find.byType(AppColorSwatchButton);
      expect(tester.getSize(target), const Size(48, 48));
      expect(
        tester.getSize(find.byType(AnimatedContainer)),
        const Size(AppSizes.chipHeight, AppSizes.chipHeight),
      );
      final ink = tester.widget<InkWell>(find.byType(InkWell));
      expect(ink.customBorder, isA<CircleBorder>());
      expect(find.byType(Material), findsWidgets);
      await tester.tapAt(tester.getTopLeft(target) + const Offset(4, 4));
      expect(calls, 1);
      expect(find.byTooltip('Yellow'), findsOneWidget);
      expect(tester, meetsGuideline(androidTapTargetGuideline));
      expect(tester, meetsGuideline(labeledTapTargetGuideline));
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('selected draws the onSurface ring and a luminance-based check', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const AppColorSwatchButton(
          color: Color(0xFFFFF59D),
          selected: true,
          tooltip: 'Yellow',
          onPressed: _noop,
        ),
      ),
    );
    final context = tester.element(find.byType(AppColorSwatchButton));
    final decoration = circle(tester).decoration! as BoxDecoration;
    expect(decoration.shape, BoxShape.circle);
    expect(decoration.color, const Color(0xFFFFF59D));
    final border = decoration.border! as Border;
    expect(border.top.width, 2);
    expect(
      border.top.color,
      context.colors.onSurface.withValues(
        alpha: AppColorSwatchButton.selectedRingAlpha,
      ),
    );
    final check = tester.widget<Icon>(find.byIcon(AppIcons.check));
    expect(check.color, context.appColors.onLightSwatch);
    expect(check.size, AppIconSize.xs);
  });

  testWidgets('dark swatch uses the dark-swatch ink; resting has no check', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const AppColorSwatchButton(
          color: Color(0xFF4A148C),
          selected: true,
          tooltip: 'Purple',
          onPressed: _noop,
        ),
      ),
    );
    final context = tester.element(find.byType(AppColorSwatchButton));
    expect(
      tester.widget<Icon>(find.byIcon(AppIcons.check)).color,
      context.appColors.onDarkSwatch,
    );

    await tester.pumpWidget(
      host(
        const AppColorSwatchButton(
          color: Color(0xFF4A148C),
          selected: false,
          tooltip: 'Purple',
          onPressed: _noop,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(AppIcons.check), findsNothing);
    final border =
        (circle(tester).decoration! as BoxDecoration).border! as Border;
    expect(border.top.width, 1);
    expect(
      border.top.color,
      context.colors.onSurface.withValues(
        alpha: AppColorSwatchButton.restingRingAlpha,
      ),
    );
  });

  testWidgets('exposes button, selected state, label and hint semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        host(
          const AppColorSwatchButton(
            color: Color(0xFFFFF59D),
            selected: true,
            tooltip: 'Yellow',
            semanticsLabel: 'Yellow highlight color',
            onTapHint: 'Select highlight color',
            onPressed: _noop,
          ),
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Yellow highlight color')),
        matchesSemantics(
          label: 'Yellow highlight color',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
          hasEnabledState: true,
          isEnabled: true,
          onTapHint: 'Select highlight color',
        ),
      );

      await tester.pumpWidget(
        host(
          const AppColorSwatchButton(
            color: Color(0xFFFFF59D),
            selected: false,
            tooltip: 'Yellow',
            onPressed: null,
          ),
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Yellow')),
        matchesSemantics(
          label: 'Yellow',
          isButton: true,
          hasSelectedState: true,
          isSelected: false,
          hasEnabledState: true,
          isEnabled: false,
        ),
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('selection change settles in one pump under reduced motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const AppColorSwatchButton(
          color: Color(0xFFFFF59D),
          selected: false,
          tooltip: 'Yellow',
          onPressed: _noop,
        ),
        reduceMotion: true,
      ),
    );
    expect(circle(tester).duration, Duration.zero);
    await tester.pumpWidget(
      host(
        const AppColorSwatchButton(
          color: Color(0xFFFFF59D),
          selected: true,
          tooltip: 'Yellow',
          onPressed: _noop,
        ),
        reduceMotion: true,
      ),
    );
    await tester.pump();
    // Zero duration: the DecoratedBox below the AnimatedContainer already
    // carries the final border after a single frame.
    final decorated = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(AnimatedContainer),
        matching: find.byType(DecoratedBox),
      ),
    );
    expect(
      ((decorated.decoration as BoxDecoration).border! as Border).top.width,
      2,
    );
    expect(tester.hasRunningAnimations, isFalse);

    await tester.pumpWidget(
      host(
        const AppColorSwatchButton(
          color: Color(0xFFFFF59D),
          selected: false,
          tooltip: 'Yellow',
          onPressed: _noop,
        ),
      ),
    );
    expect(circle(tester).duration, AppMotion.quick);
  });
}

void _noop() {}
