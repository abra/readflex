import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vellum/vellum.dart';

void main() {
  // The layer fills a 400×600 box; the image sits in the middle 300×450.
  const layerSize = Size(400, 600);
  const imageRect = Rect.fromLTWH(50, 75, 300, 450);
  const press = Duration(milliseconds: 300);

  late FixedPagesController controller;
  late ComicImageAreaDraft draft;
  late List<Rect> committed;
  late List<ComicImageArea> pressedAreas;
  var cancelled = 0;

  setUp(() {
    controller = FixedPagesController(pageCount: 3, rtl: false);
    draft = ComicImageAreaDraft();
    committed = [];
    pressedAreas = [];
    cancelled = 0;
  });

  tearDown(() {
    controller.dispose();
    draft.dispose();
  });

  Future<void> pumpLayer(
    WidgetTester tester, {
    List<ComicImageArea> areas = const [],
    bool enabled = true,
    int page = 0,
    Widget? after,
  }) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox.fromSize(
              size: layerSize,
              child: ComicImageAreaLayer(
                page: page,
                imageRect: imageRect,
                controller: controller,
                draft: draft,
                areas: areas,
                enabled: enabled,
                onDraftCommitted: (rect, _) => committed.add(rect),
                onDraftCancelled: () => cancelled++,
                onAreaPressed: (area, _) => pressedAreas.add(area),
              ),
            ),
            ?after,
          ],
        ),
      ),
    );
  }

  Color draftColorOnScreen(WidgetTester tester) {
    final paint = tester.widget<CustomPaint>(
      find
          .descendant(
            of: find.byType(ComicImageAreaLayer),
            matching: find.byType(CustomPaint),
          )
          .first,
    );
    return (paint.painter as dynamic).draftColor as Color;
  }

  Offset layerPoint(WidgetTester tester, Offset local) =>
      tester.getTopLeft(find.byType(ComicImageAreaLayer)) + local;

  /// Fractions of the image for a layer-local point.
  Offset imagePoint(Offset local) => Offset(
    (local.dx - imageRect.left) / imageRect.width,
    (local.dy - imageRect.top) / imageRect.height,
  );

  testWidgets('a long press creates a draft at the finger and locks input', (
    tester,
  ) async {
    await pumpLayer(tester);
    const local = Offset(200, 300);
    final gesture = await tester.startGesture(layerPoint(tester, local));
    await tester.pump(const Duration(milliseconds: 200));
    expect(draft.isActive, isFalse, reason: 'shorter than the long press');
    await tester.pump(const Duration(milliseconds: 100));
    expect(draft.isActive, isTrue);
    expect(draft.page, 0);
    expect(draft.rect!.center.dx, closeTo(imagePoint(local).dx, 1e-6));
    expect(draft.rect!.center.dy, closeTo(imagePoint(local).dy, 1e-6));
    expect(controller.inputLocked, isTrue);
    expect(committed, hasLength(1));

    // Still holding: the draft follows the finger, then commits on release.
    await gesture.moveBy(const Offset(30, 0));
    await tester.pump();
    expect(
      draft.rect!.center.dx,
      closeTo(imagePoint(const Offset(230, 300)).dx, 1e-6),
    );
    await gesture.up();
    await tester.pump();
    expect(committed, hasLength(2));
    expect(committed.last, draft.rect);
  });

  testWidgets('outside a pages view the commit carries no viewport rect', (
    tester,
  ) async {
    Rect? viewport = const Rect.fromLTWH(1, 1, 1, 1);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox.fromSize(
            size: layerSize,
            child: ComicImageAreaLayer(
              page: 0,
              imageRect: imageRect,
              controller: controller,
              draft: draft,
              onDraftCommitted: (_, rect) => viewport = rect,
            ),
          ),
        ),
      ),
    );
    await tester.longPressAt(layerPoint(tester, const Offset(200, 300)));
    await tester.pump(press);
    expect(draft.isActive, isTrue);
    expect(viewport, isNull);
  });

  testWidgets('a long press outside the image does nothing', (tester) async {
    await pumpLayer(tester);
    await tester.longPressAt(layerPoint(tester, const Offset(10, 10)));
    await tester.pump(press);
    expect(draft.isActive, isFalse);
    expect(controller.inputLocked, isFalse);
  });

  testWidgets('after release a drag inside moves and a corner drag resizes', (
    tester,
  ) async {
    await pumpLayer(tester);
    await tester.longPressAt(layerPoint(tester, const Offset(200, 300)));
    await tester.pump(press);
    final created = draft.rect!;

    // Move from the middle.
    final centre = layerPoint(
      tester,
      imageRect.topLeft +
          Offset(
            created.center.dx * imageRect.width,
            created.center.dy * imageRect.height,
          ),
    );
    await tester.dragFrom(centre, const Offset(-30, 15));
    await tester.pump();
    expect(draft.rect!.size, created.size);
    expect(
      draft.rect!.left,
      closeTo(created.left - 30 / imageRect.width, 1e-6),
    );
    expect(draft.rect!.top, closeTo(created.top + 15 / imageRect.height, 1e-6));
    expect(committed, hasLength(3));

    // Resize from the bottom-right corner zone.
    final moved = draft.rect!;
    final corner = layerPoint(
      tester,
      imageRect.topLeft +
          Offset(
            moved.right * imageRect.width - 4,
            moved.bottom * imageRect.height - 4,
          ),
    );
    await tester.dragFrom(corner, const Offset(30, 30));
    await tester.pump();
    expect(draft.rect!.topLeft, moved.topLeft);
    expect(
      draft.rect!.width,
      closeTo(moved.width + 30 / imageRect.width, 1e-6),
    );
    expect(
      draft.rect!.height,
      closeTo(moved.height + 30 / imageRect.height, 1e-6),
    );
    expect(committed, hasLength(4));
  });

  testWidgets('a colour change during build repaints after the frame', (
    tester,
  ) async {
    await pumpLayer(tester);
    await tester.longPressAt(layerPoint(tester, const Offset(200, 300)));
    await tester.pump(press);
    final before = draftColorOnScreen(tester);
    const red = Color(0xFFFF0000);
    expect(before, isNot(red));
    // The app previews a colour from a popup's initState: a sibling built
    // after the layer in the same frame.
    await pumpLayer(
      tester,
      after: Builder(
        builder: (_) {
          draft.setStyle(color: red);
          return const SizedBox.shrink();
        },
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.pump();
    expect(draftColorOnScreen(tester), red);
    expect(draft.isActive, isTrue);
  });

  testWidgets('a tap outside cancels the draft unless it is retained', (
    tester,
  ) async {
    await pumpLayer(tester);
    await tester.longPressAt(layerPoint(tester, const Offset(200, 300)));
    await tester.pump(press);
    expect(draft.isActive, isTrue);

    draft.retain(true);
    await tester.pump();
    await tester.tapAt(layerPoint(tester, const Offset(60, 85)));
    await tester.pump();
    expect(draft.isActive, isTrue);
    expect(cancelled, 0);

    draft.retain(false);
    await tester.pump();
    await tester.tapAt(layerPoint(tester, const Offset(200, 300)));
    await tester.pump();
    expect(draft.isActive, isTrue, reason: 'a tap inside keeps it');

    await tester.tapAt(layerPoint(tester, const Offset(60, 85)));
    await tester.pump();
    expect(draft.isActive, isFalse);
    expect(cancelled, 1);
    expect(controller.inputLocked, isFalse);
  });

  testWidgets('a long press on a saved area reports the area, topmost first', (
    tester,
  ) async {
    const under = ComicImageArea(
      id: 'a',
      page: 0,
      rect: Rect.fromLTWH(0.1, 0.1, 0.5, 0.5),
      color: Color(0xFF00FF00),
    );
    const over = ComicImageArea(
      id: 'b',
      page: 0,
      rect: Rect.fromLTWH(0.3, 0.3, 0.5, 0.5),
      color: Color(0xFFFF0000),
    );
    const elsewhere = ComicImageArea(
      id: 'c',
      page: 1,
      rect: Rect.fromLTWH(0, 0, 1, 1),
      color: Color(0xFF0000FF),
    );
    await pumpLayer(tester, areas: const [under, over, elsewhere]);

    final inBoth = layerPoint(
      tester,
      imageRect.topLeft + Offset(0.4 * imageRect.width, 0.4 * imageRect.height),
    );
    await tester.longPressAt(inBoth);
    await tester.pump(press);
    expect(pressedAreas, [over]);
    expect(draft.isActive, isFalse);

    final onlyUnder = layerPoint(
      tester,
      imageRect.topLeft +
          Offset(0.15 * imageRect.width, 0.15 * imageRect.height),
    );
    await tester.longPressAt(onlyUnder);
    await tester.pump(press);
    expect(pressedAreas, [over, under]);

    final free = layerPoint(
      tester,
      imageRect.topLeft + Offset(0.9 * imageRect.width, 0.1 * imageRect.height),
    );
    await tester.longPressAt(free);
    await tester.pump(press);
    expect(
      draft.isActive,
      isTrue,
      reason: 'the other page\'s area does not cover this page',
    );
  });

  testWidgets('a disabled layer draws areas but takes no input', (
    tester,
  ) async {
    const area = ComicImageArea(
      id: 'a',
      page: 0,
      rect: Rect.fromLTWH(0.1, 0.1, 0.5, 0.5),
      color: Color(0xFF00FF00),
    );
    await pumpLayer(tester, areas: const [area], enabled: false);
    await tester.longPressAt(layerPoint(tester, const Offset(200, 300)));
    await tester.pump(press);
    expect(draft.isActive, isFalse);
    expect(pressedAreas, isEmpty);
    expect(find.byType(CustomPaint), findsOneWidget);
  });

  testWidgets('a draft on another page is not drawn or edited here', (
    tester,
  ) async {
    await pumpLayer(tester, page: 2);
    draft.start(0, const Rect.fromLTWH(0.1, 0.1, 0.2, 0.2));
    await tester.pump();
    await tester.tapAt(layerPoint(tester, const Offset(60, 85)));
    await tester.pump();
    expect(draft.isActive, isTrue, reason: 'page 2 has no draft to cancel');
  });

  testWidgets('clearing the draft from the app ends an edit', (tester) async {
    await pumpLayer(tester);
    final gesture = await tester.startGesture(
      layerPoint(tester, const Offset(200, 300)),
    );
    await tester.pump(press);
    expect(draft.isActive, isTrue);
    draft.clear();
    await tester.pump();
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(draft.isActive, isFalse);
    expect(committed, hasLength(1));
  });

  group('goldens', () {
    testWidgets('saved areas and a draft with corner marks', (tester) async {
      const area = ComicImageArea(
        id: 'a',
        page: 0,
        rect: Rect.fromLTWH(0.1, 0.1, 0.4, 0.2),
        color: Color(0xFF2ECC71),
      );
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox.fromSize(
              size: layerSize,
              child: ColoredBox(
                color: const Color(0xFF505050),
                child: ComicImageAreaLayer(
                  page: 0,
                  imageRect: imageRect,
                  controller: controller,
                  draft: draft,
                  areas: const [area],
                ),
              ),
            ),
          ),
        ),
      );
      draft.start(0, const Rect.fromLTWH(0.3, 0.5, 0.4, 0.3));
      await tester.pump();
      await expectLater(
        find.byType(ComicImageAreaLayer),
        matchesGoldenFile('goldens/comic_image_area_layer.png'),
      );
    });
  });
}
