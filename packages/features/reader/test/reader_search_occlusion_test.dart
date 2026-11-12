import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_search_occlusion.dart';

void main() {
  test('the hit spans under the bar: clipped, merged, nothing else', () {
    final spans = occludedSearchSpans(
      const [
        Rect.fromLTRB(100, 710, 150, 740), // two covered lines
        Rect.fromLTRB(120, 755, 180, 785),
        Rect.fromLTRB(230, 685, 260, 715), // partly covered
        Rect.fromLTRB(-10, 710, 20, 740), // clipped at the sides
        Rect.fromLTRB(380, 710, 420, 740),
        Rect.fromLTRB(50, 660, 100, 690), // above the bar
        Rect.fromLTRB(60, 805, 100, 840), // below the view
        Rect.fromLTRB(410, 710, 430, 740), // beside the view
        Rect.fromLTRB(double.nan, 710, 50, 740),
        Rect.fromLTRB(20, 730, 10, 750), // empty
      ],
      const Size(390, 800),
      0.125,
    );
    expect(spans, [
      (left: 0.0, width: 20.0),
      (left: 100.0, width: 80.0),
      (left: 230.0, width: 30.0),
      (left: 380.0, width: 10.0),
    ]);
  });

  test('no bar, or a bar over everything, marks nothing', () {
    const rects = [Rect.fromLTRB(10, 790, 50, 799)];
    expect(occludedSearchSpans(rects, const Size(390, 800), 0), isEmpty);
    expect(occludedSearchSpans(rects, const Size(390, 800), 1), isEmpty);
    expect(occludedSearchSpans(rects, Size.zero, 0.2), isEmpty);
  });

  testWidgets('the marker sits on the bar edge and follows the hit', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final rects = ValueNotifier<List<Rect>>(const []);
    addTearDown(rects.dispose);
    await tester.pumpWidget(
      ReaderSearchOcclusionMarker(rects: rects, bottomInset: 0.125),
    );
    final box = tester.renderObject<RenderBox>(
      find.byType(ReaderSearchOcclusionMarker),
    );
    expect(box, isNot(paints..rrect()));
    rects.value = const [Rect.fromLTRB(100, 710, 150, 740)];
    await tester.pump();
    expect(
      box,
      paints..rrect(
        rrect: RRect.fromRectAndRadius(
          const Rect.fromLTWH(100, 696, 50, 4),
          const Radius.circular(2),
        ),
        color: readerSearchOcclusionColor,
      ),
    );
    // Back in view above the bar: gone.
    rects.value = const [Rect.fromLTRB(100, 300, 150, 330)];
    await tester.pump();
    expect(box, isNot(paints..rrect()));
    expect(
      tester
          .widget<IgnorePointer>(
            find.descendant(
              of: find.byType(ReaderSearchOcclusionMarker),
              matching: find.byType(IgnorePointer),
            ),
          )
          .ignoring,
      isTrue,
    );
  });
}
