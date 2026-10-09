import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final (theme, width) in [
    (AppTheme.light(), 190.0),
    (AppTheme.light(), 400.0),
    (AppTheme.dark(), 190.0),
    (AppTheme.dark(), 400.0),
  ]) {
    testWidgets('the selected choice is an accent wash with readable accent '
        'text: ${theme.brightness} at width $width', (tester) async {
      var enabled = true;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: SizedBox(
              width: width,
              child: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return AppChoiceControl<int>(
                    selected: 0,
                    onChanged: enabled ? (_) {} : null,
                    options: const [
                      AppChoiceOption(value: 0, label: 'System'),
                      AppChoiceOption(value: 1, label: 'Light'),
                      AppChoiceOption(value: 2, label: 'Dark'),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
      Color background(String label) => Color.alphaBlend(
        tester
            .element(find.text(label))
            .findAncestorWidgetOfExactType<Material>()!
            .color!,
        theme.colorScheme.surface,
      );
      Color foreground(String label) =>
          DefaultTextStyle.of(tester.element(find.text(label))).style.color!;
      final colors = theme.colorScheme;
      final selectedFill = background('System');
      // Both themes tint the accent behind the selected option; dark mode
      // no longer paints the brightest opaque block on the screen.
      expect(
        selectedFill,
        Color.alphaBlend(colors.selectedControlBackground, colors.surface),
      );
      expect(selectedFill.computeLuminance(), lessThan(.9));
      expect(_contrast(selectedFill, background('Light')), greaterThan(1.05));
      expect(foreground('System'), colors.selectedControlForeground);
      expect(foreground('Light'), isNot(foreground('System')));
      expect(
        _contrast(foreground('System'), selectedFill),
        greaterThanOrEqualTo(4.5),
      );
      update(() => enabled = false);
      await tester.pumpAndSettle();
      // Disabled keeps which option is chosen and dims its text.
      expect(background('System'), selectedFill);
      expect(
        foreground('System'),
        colors.onSurface.withValues(alpha: .38),
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final direction in TextDirection.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('choices stay readable and selectable $direction/$scale', (
        tester,
      ) async {
        var selected = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Directionality(
                  textDirection: direction,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: 272,
                      child: StatefulBuilder(
                        builder: (context, setState) => AppChoiceControl<int>(
                          selected: selected,
                          options: const [
                            AppChoiceOption(value: 0, label: 'System'),
                            AppChoiceOption(value: 1, label: 'Light'),
                            AppChoiceOption(value: 2, label: 'Dark'),
                          ],
                          onChanged: (value) =>
                              setState(() => selected = value),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        for (final label in ['System', 'Light', 'Dark']) {
          final paragraph = tester.renderObject<RenderParagraph>(
            find.text(label),
          );
          expect(paragraph.didExceedMaxLines, isFalse);
          final button = find.ancestor(
            of: find.text(label),
            matching: find.byWidgetPredicate(
              (widget) => widget is ButtonStyleButton,
            ),
          );
          expect(tester.getSize(button.first).height, greaterThanOrEqualTo(48));
          final style = DefaultTextStyle.of(
            tester.element(find.text(label)),
          ).style;
          expect(style.fontFamily, AppTypography.fontFamilySans);
        }
        await tester.tap(find.text('Dark'));
        await tester.pumpAndSettle();
        expect(selected, 2);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('disabled choice does not dispatch an action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: SizedBox(
            width: 200,
            child: AppChoiceControl(
              selected: 0,
              onChanged: null,
              options: [
                AppChoiceOption(value: 0, label: 'List'),
                AppChoiceOption(value: 1, label: 'Grid'),
              ],
            ),
          ),
        ),
      ),
    );
    expect(
      tester
          .widget<SegmentedButton<int>>(find.byType(SegmentedButton<int>))
          .onSelectionChanged,
      isNull,
    );
    await tester.tap(find.text('Grid'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SegmentedButton<int>>(find.byType(SegmentedButton<int>))
          .selected,
      {0},
    );
  });

  group('glyph options', () {
    Widget host({
      required int selected,
      required ValueChanged<int> onChanged,
      bool reselectable = false,
      double width = 200,
    }) => MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: AppChoiceControl<int>(
              selected: selected,
              iconOnly: true,
              reselectable: reselectable,
              onChanged: onChanged,
              options: [
                for (final value in [0, 1, 2])
                  AppChoiceOption(
                    value: value,
                    label: 'Preset $value',
                    glyph: _ProbeGlyph(key: ValueKey('glyph-$value')),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    testWidgets('paint in the icon box with the segment icon color', (
      tester,
    ) async {
      await tester.pumpWidget(host(selected: 1, onChanged: (_) {}));
      final context = tester.element(find.byType(AppChoiceControl<int>));
      Color glyphColor(int value) => tester
          .widget<_ProbeColor>(
            find.descendant(
              of: find.byKey(ValueKey('glyph-$value')),
              matching: find.byType(_ProbeColor),
            ),
          )
          .color;

      expect(glyphColor(1), context.colors.selectedControlForeground);
      expect(glyphColor(0), isNot(glyphColor(1)));
      for (final value in [0, 1, 2]) {
        final glyph = tester.getRect(find.byKey(ValueKey('glyph-$value')));
        expect(glyph.size, const Size.square(AppIconSize.sm));
        final segment = tester.getRect(
          find
              .ancestor(
                of: find.byKey(ValueKey('glyph-$value')),
                matching: find.byType(InkWell),
              )
              .first,
        );
        expect(glyph.center.dx, closeTo(segment.center.dx, 0.5));
        expect(segment.height, AppSizes.buttonHeight);
        expect(find.byTooltip('Preset $value'), findsOneWidget);
      }
    });

    testWidgets('tap on the selected glyph is ignored unless reselectable', (
      tester,
    ) async {
      final changes = <int>[];
      await tester.pumpWidget(host(selected: 1, onChanged: changes.add));
      await tester.tap(find.byKey(const ValueKey('glyph-1')));
      await tester.pumpAndSettle();
      expect(changes, isEmpty);

      await tester.pumpWidget(
        host(selected: 1, reselectable: true, onChanged: changes.add),
      );
      await tester.tap(find.byKey(const ValueKey('glyph-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('glyph-2')));
      await tester.pumpAndSettle();
      expect(changes, [1, 2]);
    });
  });
}

double _contrast(Color a, Color b) {
  final first = a.computeLuminance() + .05;
  final second = b.computeLuminance() + .05;
  return first > second ? first / second : second / first;
}

/// Reports the ambient icon color so tests can read the segment state.
class _ProbeGlyph extends StatelessWidget {
  const _ProbeGlyph({super.key});

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: AppIconSize.sm,
    child: _ProbeColor(color: IconTheme.of(context).color!),
  );
}

class _ProbeColor extends StatelessWidget {
  const _ProbeColor({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => ColoredBox(color: color);
}
