import 'package:component_library/component_library.dart';
import 'package:component_library/src/search_field_hint.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A [SearchField] hint shortens instead of being cut, and stays the same
/// hint for screen readers, layout queries and styling.
void main() {
  const full = 'Search chapters';
  const compact = 'Search';

  Future<void> pump(
    WidgetTester tester, {
    required double width,
    double scale = 1,
    TextDirection direction = TextDirection.ltr,
    Widget Function(Widget field)? wrap,
    bool withCompact = true,
    String hintText = full,
  }) async {
    final field = SizedBox(
      width: width,
      child: SearchField(
        hintText: hintText,
        compactHintText: withCompact ? compact : null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: Directionality(textDirection: direction, child: child!),
        ),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: wrap?.call(field) ?? field,
          ),
        ),
      ),
    );
  }

  RenderSearchFieldHint hint(WidgetTester tester) =>
      tester.renderObject<RenderSearchFieldHint>(find.byType(SearchFieldHint));

  testWidgets('a hint that fits is shown in full', (tester) async {
    await pump(tester, width: 360);
    expect(hint(tester).shownText, full);
  });

  testWidgets('a hint that would be cut is replaced by the compact one', (
    tester,
  ) async {
    await pump(tester, width: 200, scale: 2);
    final render = hint(tester);
    expect(render.shownText, compact);
    expect(render.size.width, lessThanOrEqualTo(200));
    expect(tester.takeException(), isNull);
  });

  testWidgets('an even narrower field ellipsizes the compact hint in its box', (
    tester,
  ) async {
    await pump(tester, width: 110, scale: 2);
    final render = hint(tester);
    expect(render.shownText, compact);
    final field = tester.getRect(find.byType(SearchField));
    final painted = tester.getRect(find.byType(SearchFieldHint));
    expect(painted.right, lessThanOrEqualTo(field.right));
    expect(tester.takeException(), isNull);
  });

  testWidgets('screen readers hear the full hint whichever one is shown', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, width: 200, scale: 2);
    expect(hint(tester).shownText, compact);
    expect(find.bySemanticsLabel(full), findsOneWidget);
    expect(find.bySemanticsLabel(compact), findsNothing);
    semantics.dispose();
  });

  testWidgets('the shown hint follows width and text scale changes', (
    tester,
  ) async {
    // The test font draws every glyph as a square of the font size.
    await pump(tester, width: 200, scale: 2);
    expect(hint(tester).shownText, compact);
    await pump(tester, width: 700, scale: 2);
    expect(hint(tester).shownText, full);
    await pump(tester, width: 360);
    expect(hint(tester).shownText, full);
  });

  // Pixels, not rects: a plain hint's box spans the field in both
  // directions, so only the paint shows its alignment, size and color.
  for (final direction in TextDirection.values) {
    for (final (name, width, scale, shown) in [
      ('full', 360.0, 1.0, full),
      ('compact', 200.0, 2.0, compact),
    ]) {
      testWidgets(
        'a $name hint paints exactly like a plain hint ($direction)',
        (
          tester,
        ) async {
          Widget boundary(Widget field) => RepaintBoundary(child: field);
          await pump(
            tester,
            width: width,
            scale: scale,
            direction: direction,
            withCompact: false,
            hintText: shown,
            wrap: boundary,
          );
          final plain = await captureImage(
            tester.element(find.byType(SearchField)),
          );
          addTearDown(plain.dispose);
          await pump(
            tester,
            width: width,
            scale: scale,
            direction: direction,
            wrap: boundary,
          );
          expect(hint(tester).shownText, shown);
          await expectLater(
            find.byType(SearchField),
            matchesReferenceImage(plain),
          );
        },
      );
    }
  }

  testWidgets(
    'intrinsic and dry layout queries work and leave the paint alone',
    (
      tester,
    ) async {
      await pump(
        tester,
        width: 200,
        scale: 2,
        wrap: (field) => IntrinsicHeight(child: IntrinsicWidth(child: field)),
      );
      expect(tester.takeException(), isNull);
      final render = hint(tester);
      expect(render.shownText, compact);
      expect(
        render.getMaxIntrinsicWidth(double.infinity),
        greaterThan(render.getMinIntrinsicWidth(double.infinity)),
      );
      final dry = render.getDryLayout(const BoxConstraints(maxWidth: 1000));
      expect(dry.width, render.getMaxIntrinsicWidth(double.infinity));
      expect(
        render.getDryBaseline(
          const BoxConstraints(maxWidth: 1000),
          TextBaseline.alphabetic,
        ),
        isNotNull,
      );
      expect(render.shownText, compact, reason: 'queries use throwaway copies');
    },
  );
}
