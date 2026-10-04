import 'dart:ui' show SemanticsAction, Tristate;

import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final direction in TextDirection.values) {
      for (final compact in [false, true]) {
        final profile =
            '${platform.name}/${direction.name}/'
            '${compact ? 'compact-large-text' : 'regular'}';

        testWidgets('choices expose selection and disabled state: $profile', (
          tester,
        ) async {
          var selected = 0;
          var enabled = true;
          var changes = 0;
          late StateSetter update;
          await _pumpControl(
            tester,
            platform: platform,
            direction: direction,
            compact: compact,
            child: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return AppChoiceControl<int>(
                  selected: selected,
                  options: const [
                    AppChoiceOption(value: 0, label: 'System'),
                    AppChoiceOption(value: 1, label: 'Light'),
                    AppChoiceOption(value: 2, label: 'Dark'),
                  ],
                  onChanged: enabled
                      ? (value) => setState(() {
                          selected = value;
                          changes++;
                        })
                      : null,
                );
              },
            ),
          );

          void expectChoice(String label, {required bool isSelected}) {
            final data = tester
                .getSemantics(find.bySemanticsLabel(label))
                .getSemanticsData();
            expect(data.flagsCollection.isButton, isTrue);
            expect(data.flagsCollection.isInMutuallyExclusiveGroup, isTrue);
            expect(
              data.flagsCollection.isSelected,
              isSelected ? Tristate.isTrue : Tristate.isFalse,
            );
            expect(
              data.flagsCollection.isEnabled,
              enabled ? Tristate.isTrue : Tristate.isFalse,
            );
            expect(data.hasAction(SemanticsAction.tap), enabled);
          }

          expectChoice('System', isSelected: true);
          expectChoice('Light', isSelected: false);
          expectChoice('Dark', isSelected: false);
          await _expectAccessibleTargets(tester, platform);
          final before = tester.getRect(find.byType(AppChoiceControl<int>));

          await tester.tap(find.bySemanticsLabel('Dark'));
          await tester.pumpAndSettle();
          expect(changes, 1);
          expectChoice('System', isSelected: false);
          expectChoice('Dark', isSelected: true);
          expect(tester.getRect(find.byType(AppChoiceControl<int>)), before);

          update(() => enabled = false);
          await tester.pumpAndSettle();
          expectChoice('Dark', isSelected: true);
          expectChoice('Light', isSelected: false);
          await tester.tap(find.text('Light'));
          expect(changes, 1);
          expect(tester.getRect(find.byType(AppChoiceControl<int>)), before);
          expect(tester.takeException(), isNull);
        });

        testWidgets('busy sheet actions remain named and stable: $profile', (
          tester,
        ) async {
          var busy = false;
          var commands = 0;
          late StateSetter update;
          await _pumpControl(
            tester,
            platform: platform,
            direction: direction,
            compact: compact,
            child: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return AppSheetActions(
                  primaryLabel: 'Save changes',
                  onPrimary: () => commands++,
                  secondaryLabel: 'Keep editing',
                  onSecondary: () => commands++,
                  busy: busy,
                );
              },
            ),
          );
          await _expectAccessibleTargets(tester, platform);
          final primary = find.byType(FilledButton);
          final secondary = find.byType(OutlinedButton);
          final primaryRect = tester.getRect(primary);
          final secondaryRect = tester.getRect(secondary);

          update(() => busy = true);
          // A busy indicator intentionally never settles.
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
          expect(tester.getRect(primary), primaryRect);
          expect(tester.getRect(secondary), secondaryRect);
          for (final label in ['Save changes', 'Keep editing']) {
            final data = tester
                .getSemantics(find.bySemanticsLabel(label))
                .getSemanticsData();
            expect(data.flagsCollection.isButton, isTrue);
            expect(data.flagsCollection.isEnabled, Tristate.isFalse);
            expect(data.hasAction(SemanticsAction.tap), isFalse);
          }
          await tester.tap(primary);
          await tester.tap(secondary);
          expect(commands, 0);

          update(() => busy = false);
          await tester.pumpAndSettle();
          await tester.tap(find.bySemanticsLabel('Save changes'));
          expect(commands, 1);
          expect(tester.getRect(primary), primaryRect);
          expect(tester.getRect(secondary), secondaryRect);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}

Future<void> _pumpControl(
  WidgetTester tester, {
  required TargetPlatform platform,
  required TextDirection direction,
  required bool compact,
  required Widget child,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light().copyWith(platform: platform),
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(
            textScaler: TextScaler.linear(compact ? 2 : 1),
          ),
          child: Directionality(
            textDirection: direction,
            child: Center(
              child: SizedBox(width: compact ? 272 : 400, child: child),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _expectAccessibleTargets(
  WidgetTester tester,
  TargetPlatform platform,
) async {
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(
    tester,
    meetsGuideline(
      platform == TargetPlatform.iOS
          ? iOSTapTargetGuideline
          : androidTapTargetGuideline,
    ),
  );
}
