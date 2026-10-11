import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_feature/src/library_progress_fill.dart';

void main() {
  const fillKey = ValueKey('fill');
  final fill = find.byKey(fillKey);
  const trackWidth = 100.0;

  Future<void> pumpFill(
    WidgetTester tester, {
    required double progress,
    bool tickersEnabled = true,
    bool reduceMotion = false,
    TextDirection direction = TextDirection.ltr,
  }) => tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Directionality(
        textDirection: direction,
        child: Center(
          child: SizedBox(
            key: const ValueKey('track'),
            width: trackWidth,
            height: 4,
            child: TickerMode(
              enabled: tickersEnabled,
              child: LibraryProgressFill(
                progress: progress,
                color: const Color(0xFF000000),
                fillKey: fillKey,
              ),
            ),
          ),
        ),
      ),
    ),
  );

  double width(WidgetTester tester) => tester.getSize(fill).width;

  group('LibraryProgressFill', () {
    testWidgets('eases to a new value', (tester) async {
      await pumpFill(tester, progress: .2);
      expect(width(tester), closeTo(20, .01));

      await pumpFill(tester, progress: .8);
      expect(width(tester), closeTo(20, .01));
      await tester.pump(const Duration(milliseconds: 100));
      expect(width(tester), inExclusiveRange(20, 80));
      await tester.pump(AppMotion.short);
      expect(width(tester), closeTo(80, .01));
    });

    testWidgets('holds a change made while covered and plays it on return', (
      tester,
    ) async {
      await pumpFill(tester, progress: .2);
      await pumpFill(tester, progress: .5, tickersEnabled: false);
      await pumpFill(tester, progress: .8, tickersEnabled: false);
      // Long after the fill's duration, as when a reader keeps reading.
      await tester.pump(const Duration(seconds: 2));
      expect(width(tester), closeTo(20, .01));

      await pumpFill(tester, progress: .8);
      expect(width(tester), closeTo(20, .01));
      await tester.pump(const Duration(milliseconds: 100));
      expect(width(tester), inExclusiveRange(20, 80));
      await tester.pump(AppMotion.short);
      expect(width(tester), closeTo(80, .01));
    });

    testWidgets('reduced motion shows the new value at once', (tester) async {
      await pumpFill(tester, progress: .2, reduceMotion: true);
      await pumpFill(tester, progress: .8, reduceMotion: true);
      await tester.pump();
      expect(width(tester), closeTo(80, .01));
    });

    testWidgets('clamps the value to the track', (tester) async {
      await pumpFill(tester, progress: 1.5);
      expect(width(tester), closeTo(trackWidth, .01));
      await pumpFill(tester, progress: -1);
      await tester.pump(AppMotion.short);
      expect(width(tester), closeTo(0, .01));
    });

    for (final direction in TextDirection.values) {
      testWidgets('fills from the start edge: $direction', (tester) async {
        await pumpFill(tester, progress: .3, direction: direction);
        final track = tester.getRect(find.byKey(const ValueKey('track')));
        final rect = tester.getRect(fill);
        if (direction == TextDirection.ltr) {
          expect(rect.left, track.left);
        } else {
          expect(rect.right, track.right);
        }
      });
    }
  });
}
