import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}
