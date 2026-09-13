import 'dart:ui' show Tristate;

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_highlight_controls.dart';
import 'package:reader/src/reader_highlight_color.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

void main() {
  testWidgets('swatches expose state and respond across the full target', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      HighlightColor? picked;
      var saved = 0;
      await _pumpControls(
        tester,
        width: 360,
        onColor: (color) => picked = color,
        onSave: () => saved++,
      );
      final selected = tester.getSemantics(find.bySemanticsLabel('Yellow'));
      expect(selected.flagsCollection.isSelected, Tristate.isTrue);
      expect(selected.flagsCollection.isButton, isTrue);
      expect(selected.flagsCollection.isEnabled, Tristate.isTrue);
      expect(
        selected.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
      );
      expect(find.byIcon(AppIcons.check), findsOneWidget);
      final green = find.byTooltip('Green');
      expect(tester.getSize(green), const Size(48, 48));
      await tester.tapAt(tester.getTopLeft(green) + const Offset(1, 1));
      expect(picked, HighlightColor.green);
      expect(saved, 0, reason: 'A color remains a preview, not a save action');
      await tester.tap(find.byTooltip('Highlight'));
      expect(saved, 1);
      final swatch = tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .first;
      expect(
        (swatch.decoration! as BoxDecoration).color,
        readerHighlightColor(
          HighlightColor.yellow,
          ReaderThemePreset.paper.data,
        ),
      );
      final swatchColor = readerHighlightColor(
        HighlightColor.yellow,
        ReaderThemePreset.paper.data,
      );
      expect(
        tester.widget<Icon>(find.byIcon(AppIcons.check)).color,
        swatchColor.computeLuminance() > 0.45
            ? Colors.black.withValues(alpha: 0.78)
            : Colors.white.withValues(alpha: 0.92),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
    'narrow palette scrolls without moving or hiding the save action',
    (
      tester,
    ) async {
      HighlightColor? picked;
      var saved = 0;
      await _pumpControls(
        tester,
        width: 280,
        onColor: (color) => picked = color,
        onSave: () => saved++,
      );
      final save = find.byTooltip('Highlight');
      final saveRect = tester.getRect(save);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(-180, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Purple'));
      expect(picked, HighlightColor.purple);
      expect(tester.getRect(save), saveRect);
      await tester.tap(save);
      expect(saved, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('saving disables palette and commands', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      var actions = 0;
      await _pumpControls(
        tester,
        width: 360,
        busy: true,
        onColor: (_) => actions++,
        onSave: () => actions++,
      );
      await tester.tap(find.byTooltip('Green'));
      await tester.tap(find.byTooltip('Highlight'));
      expect(actions, 0);
      expect(find.byType(ButtonLoadingIndicator), findsOneWidget);
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Yellow'))
            .flagsCollection
            .isEnabled,
        Tristate.isFalse,
      );
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });
}

Future<void> _pumpControls(
  WidgetTester tester, {
  required double width,
  required ValueChanged<HighlightColor> onColor,
  required VoidCallback onSave,
  bool busy = false,
}) => tester.pumpWidget(
  MaterialApp(
    theme: AppTheme.light(),
    localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
    supportedLocales: ReadflexSupportedLocales.locales,
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          height: 52,
          child: ReaderHighlightControls(
            selectedColor: HighlightColor.yellow,
            busy: busy,
            readerTheme: ReaderThemePreset.paper.data,
            dividerColor: Colors.grey,
            onColorChanged: onColor,
            actions: [
              ReaderHighlightAction(
                color: Colors.black,
                icon: AppIcons.highlight,
                tooltip: 'Highlight',
                onPressed: onSave,
                loading: busy,
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);
