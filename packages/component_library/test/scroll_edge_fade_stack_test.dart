import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Horizontal fade stacks mark the edges of a strip that hides content, on
/// the correct side for the reading direction, and only while it does.
void main() {
  const surface = Color(0xFFFAF8F4);

  Future<ScrollController> pumpStrip(
    WidgetTester tester, {
    required int items,
    TextDirection direction = TextDirection.ltr,
  }) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Directionality(
          textDirection: direction,
          child: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: 300,
                height: 48,
                child: ScrollEdgeFadeStack(
                  axis: Axis.horizontal,
                  surfaceColor: surface,
                  child: ListView(
                    controller: controller,
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (var i = 0; i < items; i++)
                        const SizedBox(width: 100),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  ScrollEdgeFade fade(WidgetTester tester, ScrollFadeEdge edge) => tester
      .widgetList<ScrollEdgeFade>(find.byType(ScrollEdgeFade))
      .singleWhere((fade) => fade.edge == edge);

  for (final direction in TextDirection.values) {
    testWidgets('a strip that overflows fades its far end first ($direction)', (
      tester,
    ) async {
      final controller = await pumpStrip(
        tester,
        items: 6,
        direction: direction,
      );
      expect(fade(tester, ScrollFadeEdge.start).visible, isFalse);
      expect(fade(tester, ScrollFadeEdge.end).visible, isTrue);

      final strip = tester.getRect(find.byType(ListView));
      final end = tester.getRect(
        find.byWidget(fade(tester, ScrollFadeEdge.end)),
      );
      // The end fade sits on the reading end: right in LTR, left in RTL.
      if (direction == TextDirection.ltr) {
        expect(end.right, strip.right);
      } else {
        expect(end.left, strip.left);
      }
      expect(end.width, ScrollEdgeFadeStack.horizontalFadeWidth);
      expect(fade(tester, ScrollFadeEdge.end).surfaceColor, surface);

      controller.jumpTo(controller.position.maxScrollExtent / 2);
      await tester.pumpAndSettle();
      expect(fade(tester, ScrollFadeEdge.start).visible, isTrue);
      expect(fade(tester, ScrollFadeEdge.end).visible, isTrue);

      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(fade(tester, ScrollFadeEdge.start).visible, isTrue);
      expect(fade(tester, ScrollFadeEdge.end).visible, isFalse);
    });
  }

  testWidgets('fade insets keep a divider under the strip whole', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 300,
              height: 48,
              child: ScrollEdgeFadeStack(
                axis: Axis.horizontal,
                fadeInsets: const EdgeInsets.only(bottom: 1),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (var i = 0; i < 6; i++) const SizedBox(width: 100),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final strip = tester.getRect(find.byType(ListView));
    final end = tester.getRect(find.byWidget(fade(tester, ScrollFadeEdge.end)));
    expect(end.top, strip.top);
    expect(end.bottom, strip.bottom - 1);
  });

  testWidgets('disabling the stack hides its fades and forgets the metrics', (
    tester,
  ) async {
    Widget strip({required bool enabled}) => MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 300,
            height: 48,
            child: ScrollEdgeFadeStack(
              axis: Axis.horizontal,
              enabled: enabled,
              child: enabled
                  ? ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (var i = 0; i < 6; i++) const SizedBox(width: 100),
                      ],
                    )
                  : const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(strip(enabled: true));
    await tester.pumpAndSettle();
    expect(fade(tester, ScrollFadeEdge.end).visible, isTrue);

    await tester.pumpWidget(strip(enabled: false));
    await tester.pumpAndSettle();
    expect(fade(tester, ScrollFadeEdge.start).visible, isFalse);
    expect(fade(tester, ScrollFadeEdge.end).visible, isFalse);

    await tester.pumpWidget(strip(enabled: true));
    await tester.pumpAndSettle();
    expect(fade(tester, ScrollFadeEdge.end).visible, isTrue);
  });

  testWidgets('a strip that fits shows no fades', (tester) async {
    await pumpStrip(tester, items: 2);
    expect(fade(tester, ScrollFadeEdge.start).visible, isFalse);
    expect(fade(tester, ScrollFadeEdge.end).visible, isFalse);
  });

  testWidgets('fades never take taps from the strip', (tester) async {
    await pumpStrip(tester, items: 6);
    expect(
      find.ancestor(
        of: find.byType(DecoratedBox),
        matching: find.byType(IgnorePointer),
      ),
      findsWidgets,
    );
  });

  testWidgets('a horizontal stack ignores vertical scrolling inside it', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SizedBox(
            height: 200,
            child: ScrollEdgeFadeStack(
              axis: Axis.horizontal,
              child: ListView(
                children: [
                  for (var i = 0; i < 10; i++) const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(fade(tester, ScrollFadeEdge.start).visible, isFalse);
    expect(fade(tester, ScrollFadeEdge.end).visible, isFalse);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is ScrollEdgeFade && widget.edge == ScrollFadeEdge.bottom,
      ),
      findsNothing,
    );
  });
}
