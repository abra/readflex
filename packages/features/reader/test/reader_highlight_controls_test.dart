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
  _swatchSizeTests();
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
      final appColors = tester.element(find.byIcon(AppIcons.check)).appColors;
      expect(
        tester.widget<Icon>(find.byIcon(AppIcons.check)).color,
        swatchColor.computeLuminance() > 0.45
            ? appColors.onLightSwatch
            : appColors.onDarkSwatch,
      );
      expect(
        find.ancestor(
          of: find.byTooltip('Highlight'),
          matching: find.byType(AppPlainIconButton),
        ),
        findsOneWidget,
      );
      expect(tester.getSize(find.byTooltip('Highlight')), const Size(48, 48));
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

  testWidgets('swatch ring snaps under reduced motion', (tester) async {
    await _pumpControls(
      tester,
      width: 360,
      onColor: (_) {},
      onSave: () {},
      disableAnimations: true,
    );
    for (final swatch in tester.widgetList<AnimatedContainer>(
      find.byType(AnimatedContainer),
    )) {
      expect(swatch.duration, Duration.zero);
    }
    await _pumpControls(tester, width: 360, onColor: (_) {}, onSave: () {});
    expect(
      tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .first
          .duration,
      AppMotion.quick,
    );
  });

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

void _swatchSizeTests() {
  testWidgets('popup swatches paint 24dp circles in 48dp targets', (
    tester,
  ) async {
    await _pumpControls(
      tester,
      width: 360,
      onColor: (_) {},
      onSave: () {},
    );
    for (final circle in find.byType(AnimatedContainer).evaluate()) {
      expect(
        tester.getSize(find.byWidget(circle.widget)),
        const Size.square(AppIconSize.md),
      );
    }
    expect(tester.getSize(find.byTooltip('Green')), const Size.square(48));
  });

  testWidgets('size widens only the painted circle', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
        supportedLocales: ReadflexSupportedLocales.locales,
        home: Scaffold(
          body: Center(
            child: ReaderHighlightColorButton(
              color: HighlightColor.green,
              readerTheme: ReaderThemePreset.paper.data,
              selected: false,
              enabled: true,
              size: AppSizes.chipHeight,
              onPressed: () {},
            ),
          ),
        ),
      ),
    );
    expect(
      tester.getSize(find.byType(AnimatedContainer)),
      const Size.square(AppSizes.chipHeight),
    );
    expect(
      tester.getSize(find.byType(ReaderHighlightColorButton)),
      const Size.square(AppSizes.buttonHeight),
    );
  });
}

Future<void> _pumpControls(
  WidgetTester tester, {
  required double width,
  required ValueChanged<HighlightColor> onColor,
  required VoidCallback onSave,
  bool busy = false,
  bool disableAnimations = false,
}) => tester.pumpWidget(
  MaterialApp(
    theme: AppTheme.light(),
    localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
    supportedLocales: ReadflexSupportedLocales.locales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(disableAnimations: disableAnimations),
      child: child!,
    ),
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
