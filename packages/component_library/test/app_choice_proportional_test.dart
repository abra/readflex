import 'dart:ui' show SemanticsAction, Tristate;

import 'package:component_library/component_library.dart';
import 'package:cupertino_ui/cupertino_ui.dart' as cupertino;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../test_support/platform_test_app.dart';

const _labels = ['A', 'B', 'Pages', 'Highlights and notes'];
const _labelStyle = TextStyle(
  fontFamily: AppTypography.fontFamilySans,
  fontSize: 12,
);
const _options = [
  AppChoiceOption(value: 0, label: 'A', labelStyle: _labelStyle),
  AppChoiceOption(value: 1, label: 'B', labelStyle: _labelStyle),
  AppChoiceOption(value: 2, label: 'Pages', labelStyle: _labelStyle),
  AppChoiceOption(
    value: 3,
    label: 'Highlights and notes',
    labelStyle: _labelStyle,
  ),
];

void main() {
  setUpAll(() async {
    await (FontLoader(AppTypography.fontFamilySans)..addFont(
          rootBundle.load('fonts/Geist-Variable.ttf'),
        ))
        .load();
  });

  for (final direction in TextDirection.values) {
    testWidgets(
      'proportional Cupertino choices fit unequal labels: $direction',
      (
        tester,
      ) async {
        await tester.pumpWidget(
          _ChoiceHost(
            direction: direction,
            child: AppChoiceControl<int>(
              selected: 0,
              options: _options,
              onChanged: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byType(cupertino.CupertinoSlidingSegmentedControl<int>),
          findsNothing,
        );
        expect(find.byType(AppButton), findsNWidgets(_options.length));
        final wrappedHeight = tester
            .getSize(find.byType(AppChoiceControl<int>))
            .height;

        await tester.pumpWidget(
          _ChoiceHost(
            direction: direction,
            child: AppChoiceControl<int>(
              selected: 0,
              proportionalWidth: true,
              options: _options,
              onChanged: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        final native = tester
            .widget<cupertino.CupertinoSlidingSegmentedControl<int>>(
              find.byType(cupertino.CupertinoSlidingSegmentedControl<int>),
            );
        expect(native.proportionalWidth, isTrue);
        expect(find.byType(AppButton), findsNothing);
        expect(
          tester.getSize(find.byType(AppChoiceControl<int>)).height,
          lessThan(wrappedHeight),
        );
        final rects = [
          for (final child in native.children.values)
            tester.getRect(find.byWidget(child)),
        ];
        for (final rect in rects) {
          expect(rect.width, greaterThanOrEqualTo(AppSizes.buttonHeight));
          expect(rect.height, greaterThanOrEqualTo(AppSizes.buttonHeight));
          expect(rect.center.dy, closeTo(rects.first.center.dy, .01));
        }
        expect(rects.last.width, greaterThan(rects.first.width));
        expect(
          rects.first.center.dx,
          direction == TextDirection.ltr
              ? lessThan(rects.last.center.dx)
              : greaterThan(rects.last.center.dx),
        );
        for (final label in _labels) {
          final paragraph = tester.renderObject<RenderParagraph>(
            find.text(label),
          );
          expect(paragraph.didExceedMaxLines, isFalse);
          expect(
            paragraph.getMaxIntrinsicWidth(double.infinity),
            lessThanOrEqualTo(paragraph.size.width + .01),
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('proportional choices retain selection and disabled semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      var selected = 0;
      var enabled = true;
      final changes = <int>[];
      late StateSetter update;
      await tester.pumpWidget(
        _ChoiceHost(
          child: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return AppChoiceControl<int>(
                selected: selected,
                proportionalWidth: true,
                options: _options,
                onChanged: enabled
                    ? (value) => setState(() {
                        selected = value;
                        changes.add(value);
                      })
                    : null,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      void expectChoice(int index) {
        final data = tester
            .getSemantics(find.bySemanticsLabel(_labels[index]))
            .getSemanticsData();
        expect(data.flagsCollection.isButton, isTrue);
        expect(data.flagsCollection.isInMutuallyExclusiveGroup, isTrue);
        expect(
          data.flagsCollection.isSelected,
          selected == index ? Tristate.isTrue : Tristate.isFalse,
        );
        expect(
          data.flagsCollection.isEnabled,
          enabled ? Tristate.isTrue : Tristate.isFalse,
        );
        expect(data.hasAction(SemanticsAction.tap), enabled);
      }

      for (var index = 0; index < _options.length; index++) {
        expectChoice(index);
      }
      await tester.tap(find.text(_labels.last));
      await tester.pumpAndSettle();
      expect(changes, [3]);
      expectChoice(0);
      expectChoice(3);
      await tester.tap(find.text(_labels.last));
      await tester.pumpAndSettle();
      expect(changes, [3]);

      update(() => selected = 1);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<cupertino.CupertinoSlidingSegmentedControl<int>>(
              find.byType(cupertino.CupertinoSlidingSegmentedControl<int>),
            )
            .groupValue,
        1,
      );
      expectChoice(1);
      expectChoice(3);

      update(() => enabled = false);
      await tester.pumpAndSettle();
      for (var index = 0; index < _options.length; index++) {
        expectChoice(index);
      }
      await tester.tap(find.text(_labels.last), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(selected, 1);
      expect(changes, [3]);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('proportional choices still wrap when large labels cannot fit', (
    tester,
  ) async {
    final changes = <int>[];
    await tester.pumpWidget(
      _ChoiceHost(
        width: 240,
        textScale: 2,
        child: AppChoiceControl<int>(
          selected: 0,
          proportionalWidth: true,
          options: _options,
          onChanged: changes.add,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byType(cupertino.CupertinoSlidingSegmentedControl<int>),
      findsNothing,
    );
    expect(find.byType(AppButton), findsNWidgets(_options.length));
    for (final label in _labels) {
      final button = find.ancestor(
        of: find.text(label),
        matching: find.byType(AppButton),
      );
      final size = tester.getSize(button);
      expect(size.width, greaterThanOrEqualTo(AppSizes.buttonHeight));
      expect(size.height, greaterThanOrEqualTo(AppSizes.buttonHeight));
      expect(
        tester
            .renderObject<RenderParagraph>(find.text(label))
            .didExceedMaxLines,
        isFalse,
      );
    }
    await tester.tap(find.text(_labels.last));
    await tester.pumpAndSettle();
    expect(changes, [3]);
    expect(tester.takeException(), isNull);
  });

  for (final width in [400.0, 800.0]) {
    testWidgets('proportional opt-in preserves Material layout at $width', (
      tester,
    ) async {
      final layouts = <List<Rect>>[];
      for (final proportionalWidth in [false, true]) {
        await tester.pumpWidget(
          _ChoiceHost(
            platform: TargetPlatform.android,
            width: width,
            child: AppChoiceControl<int>(
              selected: 0,
              proportionalWidth: proportionalWidth,
              options: _options,
              onChanged: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byType(SegmentedButton<int>),
          width == 800 ? findsOneWidget : findsNothing,
        );
        expect(
          find.byType(cupertino.CupertinoSlidingSegmentedControl<int>),
          findsNothing,
        );
        layouts.add([
          for (final label in _labels) tester.getRect(find.text(label)),
        ]);
        expect(tester.takeException(), isNull);
      }
      expect(layouts.last, layouts.first);
    });
  }
}

class _ChoiceHost extends StatelessWidget {
  const _ChoiceHost({
    required this.child,
    this.platform = TargetPlatform.iOS,
    this.width = 400,
    this.textScale = 1,
    this.direction = TextDirection.ltr,
  });

  final Widget child;
  final TargetPlatform platform;
  final double width;
  final double textScale;
  final TextDirection direction;

  @override
  Widget build(BuildContext context) => PlatformTestApp(
    platform: platform,
    textScale: textScale,
    home: Directionality(
      textDirection: direction,
      child: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(width: width, child: child),
      ),
    ),
  );
}
