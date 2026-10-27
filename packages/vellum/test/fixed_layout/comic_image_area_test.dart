import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:vellum/vellum.dart';

Matcher rectCloseTo(Rect expected) => predicate<Rect>(
  (rect) =>
      (rect.left - expected.left).abs() < 1e-9 &&
      (rect.top - expected.top).abs() < 1e-9 &&
      (rect.right - expected.right).abs() < 1e-9 &&
      (rect.bottom - expected.bottom).abs() < 1e-9,
  'a rect within 1e-9 of $expected',
);

void main() {
  group('ComicImageAreaGeometry', () {
    test('a draft is the default size centred on the press', () {
      final rect = ComicImageAreaGeometry.draftAt(const Offset(0.5, 0.5));
      expect(rect.width, closeTo(ComicImageAreaGeometry.defaultWidth, 1e-9));
      expect(rect.height, closeTo(ComicImageAreaGeometry.defaultHeight, 1e-9));
      expect(rect.center.dx, closeTo(0.5, 1e-9));
      expect(rect.center.dy, closeTo(0.5, 1e-9));
    });

    test('a draft near an edge stays inside the image', () {
      final corner = ComicImageAreaGeometry.draftAt(const Offset(0.01, 0.99));
      expect(corner.left, 0);
      expect(corner.bottom, closeTo(1, 1e-9));
      final right = ComicImageAreaGeometry.draftAt(const Offset(1, 0));
      expect(right.right, closeTo(1, 1e-9));
      expect(right.top, 0);
    });

    test('moving clamps to the image', () {
      const rect = Rect.fromLTWH(0.4, 0.4, 0.2, 0.1);
      expect(
        ComicImageAreaGeometry.move(rect, const Offset(0.1, -0.1)),
        rectCloseTo(const Rect.fromLTWH(0.5, 0.3, 0.2, 0.1)),
      );
      final clamped = ComicImageAreaGeometry.move(rect, const Offset(5, 5));
      expect(clamped.right, closeTo(1, 1e-9));
      expect(clamped.bottom, closeTo(1, 1e-9));
      expect(clamped.size, rect.size);
      expect(
        ComicImageAreaGeometry.move(rect, const Offset(-5, -5)).topLeft,
        Offset.zero,
      );
    });

    test(
      'resizing from each corner keeps the opposite corner and a minimum size',
      () {
        const rect = Rect.fromLTWH(0.4, 0.4, 0.2, 0.2);
        final se = ComicImageAreaGeometry.resize(
          rect,
          ComicAreaHandle.se,
          const Offset(0.1, 0.1),
        );
        expect(se, rectCloseTo(const Rect.fromLTRB(0.4, 0.4, 0.7, 0.7)));
        final nw = ComicImageAreaGeometry.resize(
          rect,
          ComicAreaHandle.nw,
          const Offset(-0.1, -0.1),
        );
        expect(nw, rectCloseTo(const Rect.fromLTRB(0.3, 0.3, 0.6, 0.6)));
        final ne = ComicImageAreaGeometry.resize(
          rect,
          ComicAreaHandle.ne,
          const Offset(0.1, -0.1),
        );
        expect(ne, rectCloseTo(const Rect.fromLTRB(0.4, 0.3, 0.7, 0.6)));
        final sw = ComicImageAreaGeometry.resize(
          rect,
          ComicAreaHandle.sw,
          const Offset(-0.1, 0.1),
        );
        expect(sw, rectCloseTo(const Rect.fromLTRB(0.3, 0.4, 0.6, 0.7)));

        final collapsed = ComicImageAreaGeometry.resize(
          rect,
          ComicAreaHandle.se,
          const Offset(-1, -1),
        );
        expect(collapsed.width, closeTo(ComicImageAreaGeometry.minSize, 1e-9));
        expect(collapsed.height, closeTo(ComicImageAreaGeometry.minSize, 1e-9));
        expect(collapsed.topLeft, rect.topLeft);
        final overflow = ComicImageAreaGeometry.resize(
          rect,
          ComicAreaHandle.se,
          const Offset(5, 5),
        );
        expect(overflow.bottomRight, const Offset(1, 1));
      },
    );

    test('corner zones are screen-sized, divided by zoom and capped', () {
      expect(ComicImageAreaGeometry.handleSize(const Size(400, 300), 1), 64);
      expect(ComicImageAreaGeometry.handleSize(const Size(400, 300), 2), 32);
      expect(
        ComicImageAreaGeometry.handleSize(const Size(100, 300), 1),
        40,
        reason: '40% of the short side',
      );
    });

    test('handleAt finds the corner under a point and nothing elsewhere', () {
      const drawn = Rect.fromLTWH(100, 100, 300, 200);
      expect(
        ComicImageAreaGeometry.handleAt(const Offset(110, 110), drawn, 1),
        ComicAreaHandle.nw,
      );
      expect(
        ComicImageAreaGeometry.handleAt(const Offset(390, 110), drawn, 1),
        ComicAreaHandle.ne,
      );
      expect(
        ComicImageAreaGeometry.handleAt(const Offset(110, 290), drawn, 1),
        ComicAreaHandle.sw,
      );
      expect(
        ComicImageAreaGeometry.handleAt(const Offset(390, 290), drawn, 1),
        ComicAreaHandle.se,
      );
      expect(
        ComicImageAreaGeometry.handleAt(const Offset(250, 200), drawn, 1),
        isNull,
      );
      expect(
        ComicImageAreaGeometry.handleAt(const Offset(50, 50), drawn, 1),
        isNull,
      );
      // Zoomed in, the zones shrink on the page so they stay 64 px on screen.
      expect(
        ComicImageAreaGeometry.handleAt(const Offset(150, 150), drawn, 1),
        ComicAreaHandle.nw,
      );
      expect(
        ComicImageAreaGeometry.handleAt(const Offset(150, 150), drawn, 2),
        isNull,
      );
    });

    test('areaAt returns the topmost saved area', () {
      const under = ComicImageArea(
        id: 'a',
        page: 0,
        rect: Rect.fromLTWH(0, 0, 0.5, 0.5),
        color: Color(0xFF00FF00),
      );
      const over = ComicImageArea(
        id: 'b',
        page: 0,
        rect: Rect.fromLTWH(0.25, 0.25, 0.5, 0.5),
        color: Color(0xFFFF0000),
      );
      expect(
        ComicImageAreaGeometry.areaAt(const Offset(0.3, 0.3), [under, over]),
        over,
      );
      expect(
        ComicImageAreaGeometry.areaAt(const Offset(0.1, 0.1), [under, over]),
        under,
      );
      expect(
        ComicImageAreaGeometry.areaAt(const Offset(0.9, 0.9), [under, over]),
        isNull,
      );
      expect(under, isNot(over));
      expect(
        under.hashCode,
        const ComicImageArea(
          id: 'a',
          page: 0,
          rect: Rect.fromLTWH(0, 0, 0.5, 0.5),
          color: Color(0xFF00FF00),
        ).hashCode,
      );
    });
  });

  group('ComicImageAreaDraft', () {
    test('starts, updates, retains and clears with notifications', () {
      final draft = ComicImageAreaDraft();
      addTearDown(draft.dispose);
      var notified = 0;
      draft.addListener(() => notified++);
      expect(draft.isActive, isFalse);
      draft.update(const Rect.fromLTWH(0, 0, 0.1, 0.1));
      expect(notified, 0, reason: 'nothing to update');

      draft.start(2, const Rect.fromLTWH(0.1, 0.1, 0.2, 0.2));
      expect(draft.isActive, isTrue);
      expect(draft.page, 2);
      expect(notified, 1);
      draft.update(const Rect.fromLTWH(0.1, 0.1, 0.2, 0.2));
      expect(notified, 1, reason: 'same rect');
      draft.update(const Rect.fromLTWH(0.2, 0.1, 0.2, 0.2));
      expect(notified, 2);
      draft.retain(true);
      draft.retain(true);
      expect(draft.retained, isTrue);
      expect(notified, 3);
      draft.clear();
      expect(draft.isActive, isFalse);
      expect(draft.page, isNull);
      expect(draft.retained, isFalse, reason: 'clearing forgets retention');
      expect(notified, 4);
      draft.clear();
      expect(notified, 4);
    });

    test('style changes notify only when something changes', () {
      final draft = ComicImageAreaDraft();
      addTearDown(draft.dispose);
      var notified = 0;
      draft.addListener(() => notified++);
      expect(draft.color, const Color(0xFFFFE600));
      expect(draft.opacity, 0.35);
      draft.setStyle(color: const Color(0xFFFFE600), opacity: 0.35);
      expect(notified, 0);
      draft.setStyle(color: const Color(0xFF00AAFF));
      expect(draft.color, const Color(0xFF00AAFF));
      expect(draft.opacity, 0.35);
      expect(notified, 1);
      draft.setStyle(opacity: 0.5);
      expect(notified, 2);
    });
  });
}
