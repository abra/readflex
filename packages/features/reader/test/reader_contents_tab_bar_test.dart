import 'dart:ui' show Tristate;

import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_contents_tab_bar.dart';
import 'package:reader/src/reader_contents_tabs.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

const _tabs = ReaderContentsTab.values;

void main() {
  setUpAll(() async {
    await (FontLoader('Geist')..addFont(
          rootBundle.load(
            'packages/component_library/fonts/Geist-Variable.ttf',
          ),
        ))
        .load();
  });

  testWidgets('four phone tabs fill the row when unequal labels fit', (
    tester,
  ) async {
    await _pump(tester, width: 400);
    final rects = _tabRects(tester);
    expect(rects.first.left, closeTo(AppSpacing.sm, .01));
    expect(rects.last.right, closeTo(400 - AppSpacing.sm, .01));
    for (var index = 1; index < rects.length; index++) {
      expect(rects[index].left, closeTo(rects[index - 1].right, .01));
    }
    expect(rects.last.width, greaterThan(rects[1].width));
    expect(_position(tester).maxScrollExtent, closeTo(0, .01));
    expect(
      tester
          .widget<ScrollEdgeFadeStack>(find.byType(ScrollEdgeFadeStack))
          .enabled,
      isFalse,
    );
    _expectReadableLabels(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide tabs have equal full-width targets', (tester) async {
    await _pump(tester, width: 600);
    final rects = _tabRects(tester);
    for (final rect in rects) {
      expect(rect.width, closeTo((600 - 2 * AppSpacing.sm) / 4, .01));
      expect(rect.height, greaterThanOrEqualTo(AppSizes.buttonHeight));
    }
    expect(_position(tester).maxScrollExtent, closeTo(0, .01));
    _expectReadableLabels(tester);
  });

  testWidgets('large German labels scroll with the final tab reachable', (
    tester,
  ) async {
    await _pump(tester, width: 320, scale: 2, locale: const Locale('de'));
    expect(_position(tester).maxScrollExtent, greaterThan(0));
    final context = tester.element(find.byType(ReaderContentsTabBar));
    final last = find.text(context.l10n.readerHighlights);
    await tester.ensureVisible(last);
    await tester.pumpAndSettle();
    expect(last.hitTestable(), findsOneWidget);
    await tester.tap(last);
    await tester.pumpAndSettle();
    expect(DefaultTabController.of(context).index, 3);
    for (final rect in _tabRects(tester)) {
      expect(rect.width, greaterThanOrEqualTo(AppSizes.buttonHeight));
      expect(rect.height, greaterThanOrEqualTo(AppSizes.buttonHeight));
    }
    _expectReadableLabels(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone RTL mirrors tabs and retains selected semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await _pump(tester, locale: const Locale('ar'));
      final rects = _tabRects(tester);
      expect(rects.first.center.dx, greaterThan(rects.last.center.dx));
      final context = tester.element(find.byType(ReaderContentsTabBar));
      final last = find.text(context.l10n.readerHighlights);
      await tester.ensureVisible(last);
      await tester.pumpAndSettle();
      await tester.tap(last);
      await tester.pumpAndSettle();
      expect(DefaultTabController.of(context).index, 3);
      expect(
        tester.getSemantics(last).flagsCollection.isSelected,
        Tristate.isTrue,
      );
      _expectReadableLabels(tester);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
    'resizing from overflow fills the row without resetting selection',
    (
      tester,
    ) async {
      await _pump(tester, width: 320, scale: 2, locale: const Locale('de'));
      final context = tester.element(find.byType(ReaderContentsTabBar));
      final controller = DefaultTabController.of(context);
      final last = find.text(context.l10n.readerHighlights);
      await tester.ensureVisible(last);
      await tester.pumpAndSettle();
      await tester.tap(last);
      await tester.pumpAndSettle();
      expect(controller.index, 3);
      tester.view.physicalSize = const Size(1200, 844);
      await tester.pumpAndSettle();
      expect(DefaultTabController.of(context), same(controller));
      expect(controller.index, 3);
      expect(_position(tester).pixels, closeTo(0, .01));
      expect(_position(tester).maxScrollExtent, closeTo(0, .01));
      final rects = _tabRects(tester);
      expect(rects.first.left, closeTo(AppSpacing.sm, .01));
      expect(rects.last.right, closeTo(1200 - AppSpacing.sm, .01));
      expect(
        tester
            .widget<ScrollEdgeFadeStack>(find.byType(ScrollEdgeFadeStack))
            .enabled,
        isFalse,
      );
      _expectReadableLabels(tester);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _pump(
  WidgetTester tester, {
  double width = 390,
  double scale = 1,
  Locale locale = const Locale('en'),
}) async {
  tester.view
    ..physicalSize = Size(width, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_Harness(locale: locale, scale: scale));
  await tester.pumpAndSettle();
}

List<Rect> _tabRects(WidgetTester tester) => [
  for (var index = 0; index < _tabs.length; index++)
    tester.getRect(
      find
          .ancestor(
            of: find.byType(Tab).at(index),
            matching: find.byType(InkWell),
          )
          .first,
    ),
];

ScrollPosition _position(WidgetTester tester) => tester
    .state<ScrollableState>(
      find.descendant(
        of: find.byType(TabBar),
        matching: find.byType(Scrollable),
      ),
    )
    .position;

void _expectReadableLabels(WidgetTester tester) {
  final labels = find.descendant(
    of: find.byType(TabBar),
    matching: find.byType(Text),
  );
  for (var index = 0; index < labels.evaluate().length; index++) {
    final paragraph = tester.renderObject<RenderParagraph>(labels.at(index));
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(
      paragraph.getMaxIntrinsicWidth(double.infinity),
      lessThanOrEqualTo(paragraph.size.width + .01),
    );
  }
}

class _Harness extends StatelessWidget {
  const _Harness({required this.locale, required this.scale});

  final Locale locale;
  final double scale;

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: AppTheme.light(),
    locale: locale,
    supportedLocales: ReadflexSupportedLocales.locales,
    localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: const Scaffold(
      body: DefaultTabController(
        length: 4,
        child: Align(
          alignment: Alignment.topCenter,
          child: ReaderContentsTabBar(tabs: _tabs),
        ),
      ),
    ),
  );
}
