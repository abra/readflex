import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:reader/src/reader_theme_swatches.dart';

/// Theme swatches keep every name on one line: five in a row, else rows of
/// three, else one scrolling row that opens on the selected theme.
void main() {
  // The test font draws square glyphs: with its letter spacing "Graphite"
  // makes an English swatch 108 px wide, so five need 556 px and three
  // 332 px. Stored ids differ from names: `night` is Graphite, and `mist`,
  // the last, is Night.
  const englishNames = ['Snow', 'Paper', 'Warm', 'Graphite', 'Night'];
  const last = ReaderThemePreset.mist;

  Future<void> pumpSwatches(
    WidgetTester tester, {
    required double width,
    ReaderThemePreset selected = ReaderThemePreset.paper,
    Locale locale = const Locale('en'),
    TextDirection? direction,
    ValueChanged<ReaderThemePreset>? onSelected,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        supportedLocales: ReadflexSupportedLocales.locales,
        localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
        theme: AppTheme.light(),
        builder: (context, child) => direction == null
            ? child!
            : Directionality(textDirection: direction, child: child!),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: width,
              child: ReaderThemeSwatches(
                selected: selected,
                onSelected: onSelected ?? (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder swatch(ReaderThemePreset preset) =>
      find.byKey(ValueKey('reader-theme-swatch-${preset.id}'));
  Rect swatchRect(WidgetTester tester, ReaderThemePreset preset) =>
      tester.getRect(swatch(preset));
  Rect strip(WidgetTester tester) =>
      tester.getRect(find.byKey(const ValueKey('reader-theme-presets')));

  void expectOneLineNames(WidgetTester tester, List<String> names) {
    final oneLine = tester.getSize(find.text(names.first)).height;
    for (final name in names) {
      expect(tester.getSize(find.text(name)).height, oneLine, reason: name);
    }
  }

  ScrollEdgeFade fade(WidgetTester tester, ScrollFadeEdge edge) => tester
      .widgetList<ScrollEdgeFade>(find.byType(ScrollEdgeFade))
      .singleWhere((fade) => fade.edge == edge);

  testWidgets('all five sit in one row when every name fits', (tester) async {
    await pumpSwatches(tester, width: 600);
    const width = (600 - AppSpacing.xs * 4) / 5;
    final top = swatchRect(tester, ReaderThemePreset.snow).top;
    for (final preset in ReaderThemePreset.values) {
      final rect = swatchRect(tester, preset);
      expect(rect.top, top, reason: preset.id);
      expect(rect.width, closeTo(width, 1e-6), reason: preset.id);
    }
    expectOneLineNames(tester, englishNames);
    expect(find.byType(Scrollable), findsNothing);
  });

  testWidgets('rows of three take over before a name would wrap', (
    tester,
  ) async {
    await pumpSwatches(tester, width: 400);
    const width = (400 - AppSpacing.xs * 2) / 3;
    final first = swatchRect(tester, ReaderThemePreset.snow);
    for (final preset in ReaderThemePreset.values) {
      final rect = swatchRect(tester, preset);
      expect(rect.width, closeTo(width, 1e-6), reason: preset.id);
      expect(
        rect.top,
        preset.index < 3 ? first.top : first.bottom + AppSpacing.sm,
        reason: preset.id,
      );
    }
    expectOneLineNames(tester, englishNames);
  });

  testWidgets('a column holds a name with its ink, so "Бумага" stays whole', (
    tester,
  ) async {
    // Five 75 px names fit 400 px, but not with their 4 px ink on each side:
    // five columns would leave 68.8 px and break the name as "Бумаг-а".
    await pumpSwatches(tester, width: 400, locale: const Locale('ru'));
    expectOneLineNames(tester, ['Снег', 'Бумага', 'Теплая', 'Графит', 'Ночь']);
    expect(
      swatchRect(tester, last).top,
      greaterThan(swatchRect(tester, ReaderThemePreset.snow).bottom),
    );
  });

  group('too narrow for three', () {
    testWidgets('swatches scroll in one row under edge fades', (
      tester,
    ) async {
      await pumpSwatches(
        tester,
        width: 300,
        selected: ReaderThemePreset.snow,
      );
      expect(find.byType(Scrollable), findsOneWidget);
      // As wide as the widest name with its ink, rounded up.
      final width =
          (tester.getSize(find.text('Graphite')).width +
                  ReaderThemeSwatches.inkInset * 2)
              .ceilToDouble();
      expect(width, 108);
      final top = swatchRect(tester, ReaderThemePreset.snow).top;
      for (final preset in ReaderThemePreset.values) {
        final rect = swatchRect(tester, preset);
        expect(rect.width, width, reason: preset.id);
        expect(rect.top, top, reason: preset.id);
      }
      expect(
        swatchRect(tester, ReaderThemePreset.snow).left,
        strip(tester).left,
      );
      expect(fade(tester, ScrollFadeEdge.start).visible, isFalse);
      expect(fade(tester, ScrollFadeEdge.end).visible, isTrue);
      expectOneLineNames(tester, englishNames);
    });

    testWidgets('the row opens with the selected theme centered', (
      tester,
    ) async {
      await pumpSwatches(
        tester,
        width: 300,
        selected: ReaderThemePreset.warm,
      );
      expect(
        swatchRect(tester, ReaderThemePreset.warm).center.dx,
        closeTo(strip(tester).center.dx, 1e-6),
      );
      expect(fade(tester, ScrollFadeEdge.start).visible, isTrue);
      expect(fade(tester, ScrollFadeEdge.end).visible, isTrue);
    });

    for (final direction in TextDirection.values) {
      testWidgets('the last theme opens fully in view ($direction)', (
        tester,
      ) async {
        await pumpSwatches(
          tester,
          width: 300,
          selected: last,
          direction: direction,
        );
        final night = swatchRect(tester, last);
        final row = strip(tester);

        // Scrolled to the end: the reading end, right in LTR, left in RTL.
        expect(
          direction == TextDirection.ltr ? night.right : night.left,
          direction == TextDirection.ltr ? row.right : row.left,
        );
        expect(swatch(last).hitTestable(), findsOneWidget);
        expect(fade(tester, ScrollFadeEdge.start).visible, isTrue);
        expect(fade(tester, ScrollFadeEdge.end).visible, isFalse);
      });
    }

    testWidgets('a new selection keeps the reader\'s scroll position', (
      tester,
    ) async {
      var selected = ReaderThemePreset.snow;
      Future<void> pump() => pumpSwatches(
        tester,
        width: 300,
        selected: selected,
        onSelected: (preset) => selected = preset,
      );
      await pump();
      await tester.drag(find.byType(Scrollable), const Offset(-60, 0));
      await tester.pumpAndSettle();
      final scrolled = swatchRect(tester, ReaderThemePreset.warm);
      await tester.tap(swatch(ReaderThemePreset.warm));
      expect(selected, ReaderThemePreset.warm);
      await pump();
      expect(swatchRect(tester, ReaderThemePreset.warm), scrolled);
    });
  });

  testWidgets('a tap selects the theme in rows and in the scrolling row', (
    tester,
  ) async {
    for (final width in [600.0, 300.0]) {
      final taps = <ReaderThemePreset>[];
      await pumpSwatches(tester, width: width, onSelected: taps.add);
      await tester.tap(swatch(ReaderThemePreset.snow));
      await tester.tap(swatch(ReaderThemePreset.warm));
      expect(taps, [ReaderThemePreset.snow, ReaderThemePreset.warm]);
    }
  });
}
