import 'dart:ui' show SemanticsAction, Tristate;

import 'package:component_library/component_library.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_support/platform_test_app.dart';

void main() {
  setUpAll(() async {
    final font = await rootBundle.load('fonts/Geist-Variable.ttf');
    for (final family in [
      AppTypography.fontFamilySans,
      'CupertinoSystemText',
      'CupertinoSystemDisplay',
    ]) {
      // Portable metrics test reflow; native SF painting is a device check.
      await (FontLoader(family)..addFont(Future.value(font))).load();
    }
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final (direction, labels) in [
      (TextDirection.ltr, ['System', 'Light', 'Dark']),
      (TextDirection.ltr, ['System', 'Hell', 'Dunkel']),
      (TextDirection.rtl, ['النظام', 'فاتح', 'داكن']),
      (TextDirection.ltr, ['Schieben', 'Überdecken']),
      (TextDirection.rtl, ['انزلاق', 'تغطية']),
    ]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('320dp choices retain whole labels and 48dp targets '
            '$platform/$direction/${labels.last}/$scale', (tester) async {
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final semantics = tester.ensureSemantics();
          try {
            var selected = 0;
            var enabled = true;
            late StateSetter update;
            final changes = <int>[];
            await tester.pumpWidget(
              PlatformTestApp(
                platform: platform,
                textScale: scale,
                home: Directionality(
                  textDirection: direction,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: StatefulBuilder(
                        builder: (context, setState) {
                          update = setState;
                          return AppChoiceControl<int>(
                            selected: selected,
                            onChanged: enabled
                                ? (value) => setState(() {
                                    selected = value;
                                    changes.add(value);
                                  })
                                : null,
                            options: [
                              for (
                                var index = 0;
                                index < labels.length;
                                index++
                              )
                                AppChoiceOption(
                                  value: index,
                                  label: labels[index],
                                  icon: [
                                    AppIcons.deviceMode,
                                    AppIcons.lightMode,
                                    AppIcons.darkMode,
                                  ][index],
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final controlSize = tester.getSize(
              find.byType(AppChoiceControl<int>),
            );
            for (final label in labels) {
              final paragraph = tester.renderObject<RenderParagraph>(
                find.text(label),
              );
              final lines = paragraph
                  .getBoxesForSelection(
                    TextSelection(baseOffset: 0, extentOffset: label.length),
                  )
                  .map((box) => box.top)
                  .toSet();
              expect(lines, hasLength(1));
              expect(paragraph.didExceedMaxLines, isFalse);
              final node = tester.getSemantics(find.bySemanticsLabel(label));
              final data = node.getSemanticsData();
              expect(data.rect.width, greaterThanOrEqualTo(48));
              expect(data.rect.height, greaterThanOrEqualTo(48));
              expect(data.flagsCollection.isButton, isTrue);
              expect(data.flagsCollection.isInMutuallyExclusiveGroup, isTrue);
            }
            await tester.tap(find.text(labels.first));
            await tester.pumpAndSettle();
            expect(changes, isEmpty);
            await tester.tap(find.text(labels.last));
            await tester.pumpAndSettle();
            expect(changes, [labels.length - 1]);
            expect(
              tester.getSize(find.byType(AppChoiceControl<int>)),
              controlSize,
              reason: 'selected text weight must not change layout',
            );
            update(() => enabled = false);
            await tester.pumpAndSettle();
            final data = tester
                .getSemantics(find.bySemanticsLabel(labels.last))
                .getSemanticsData();
            expect(data.flagsCollection.isSelected, Tristate.isTrue);
            expect(data.flagsCollection.isEnabled, Tristate.isFalse);
            expect(data.hasAction(SemanticsAction.tap), isFalse);
            expect(tester.takeException(), isNull);
          } finally {
            semantics.dispose();
          }
        });
      }
    }
  }
}
