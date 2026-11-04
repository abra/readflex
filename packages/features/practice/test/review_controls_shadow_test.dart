import 'dart:ui' as ui;

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:practice/practice.dart';
import 'package:practice/src/practice_item.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('review dock casts a subtle contact shadow: $brightness', (
      tester,
    ) async {
      final previousDisableShadows = debugDisableShadows;
      debugDisableShadows = false;
      try {
        final rated = <Rating>[];
        await tester.pumpWidget(
          MaterialApp(
            theme: brightness == Brightness.light
                ? AppTheme.light()
                : AppTheme.dark(),
            localizationsDelegates:
                ReadflexLocalizations.localizationsDelegates,
            supportedLocales: ReadflexSupportedLocales.locales,
            home: Center(
              child: RepaintBoundary(
                key: const ValueKey('dockCapture'),
                child: SizedBox(
                  width: 320,
                  child: ReviewSessionControls(
                    item: PracticeHighlightItem(
                      highlight: Highlight(
                        id: 'passage',
                        sourceId: 'book',
                        sourceType: SourceType.book,
                        text: 'A saved passage.',
                        createdAt: DateTime(2026),
                      ),
                      fsrs: const FsrsCardData(),
                    ),
                    revealed: false,
                    intervals: const {
                      Rating.good: Duration(days: 1),
                      Rating.easy: Duration(days: 4),
                    },
                    onReveal: () {},
                    onRated: rated.add,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final capture = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('dockCapture')),
        );
        final width = capture.size.width.ceil();
        final height = capture.size.height.ceil();
        const gutter = 32;
        final imageWidth = width + gutter * 2;
        final bytes = (await tester.runAsync(() async {
          final image = await (capture.debugLayer! as OffsetLayer).toImage(
            Rect.fromLTWH(
              -gutter.toDouble(),
              -gutter.toDouble(),
              imageWidth.toDouble(),
              (height + gutter * 2).toDouble(),
            ),
          );
          try {
            return await image.toByteData(format: ui.ImageByteFormat.rawRgba);
          } finally {
            image.dispose();
          }
        }))!;
        final pixels = bytes.buffer.asUint8List(
          bytes.offsetInBytes,
          bytes.lengthInBytes,
        );
        int channel(int x, int y, int component) =>
            pixels[((y + gutter) * imageWidth + x + gutter) * 4 + component];
        int alpha(int x, int y) => channel(x, y, 3);

        final nearShadow = alpha(width ~/ 2, -1);
        expect(nearShadow, greaterThan(0));
        expect(nearShadow, lessThan(255));
        for (var distance = 12; distance <= gutter; distance++) {
          expect(
            alpha(width ~/ 2, -distance),
            0,
            reason: 'The dock must not cast a wide shadow band above its edge',
          );
        }
        for (var y = -gutter; y < height + gutter; y++) {
          for (var x = -gutter; x < width + gutter; x++) {
            if (x < 0 || x >= width || y >= height) {
              expect(
                alpha(x, y),
                0,
                reason: 'Dock shadow leaked beside/below the panel at ($x, $y)',
              );
            }
          }
        }

        final surface = tester
            .element(find.byType(ReviewSessionControls))
            .colors
            .surface;
        for (var y = 0; y < 4; y++) {
          final x = width ~/ 2;
          expect(alpha(x, y), 255, reason: 'The dock surface must be opaque');
          expect(channel(x, y, 0), (surface.r * 255).round());
          expect(channel(x, y, 1), (surface.g * 255).round());
          expect(channel(x, y, 2), (surface.b * 255).round());
        }
        expect(
          find.descendant(
            of: find.byType(ReviewSessionControls),
            matching: find.byType(Divider),
          ),
          findsNothing,
        );
        final keep = find.byKey(const ValueKey('reviewRate-keep'));
        expect(keep.hitTestable(), findsOneWidget);
        expect(tester.getSize(keep).width, greaterThanOrEqualTo(48));
        expect(tester.getSize(keep).height, greaterThanOrEqualTo(48));
        await tester.tap(keep);
        expect(rated, [Rating.good]);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      } finally {
        debugDisableShadows = previousDisableShadows;
      }
    });
  }
}
