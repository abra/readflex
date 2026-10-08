import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_layout_presets.dart';
import 'package:reader/src/reader_line_spacing_glyph.dart';
import 'package:reader/src/reader_margins_glyph.dart';

const _ink = Color(0xFF123456);

void main() {
  Future<void> pumpGlyph(
    WidgetTester tester,
    Widget glyph, {
    TextDirection direction = TextDirection.ltr,
    Color color = _ink,
  }) {
    return tester.pumpWidget(
      Directionality(
        textDirection: direction,
        child: IconTheme(
          data: IconThemeData(color: color),
          child: Center(child: glyph),
        ),
      ),
    );
  }

  Finder painterOf(Type glyph) => find.descendant(
    of: find.byType(glyph),
    matching: find.byType(CustomPaint),
  );

  group('ReaderLineSpacingGlyph', () {
    final gaps = {
      ReaderLineSpacingPreset.compact: 4.0,
      ReaderLineSpacingPreset.normal: 6.0,
      ReaderLineSpacingPreset.relaxed: 8.0,
    };

    for (final entry in gaps.entries) {
      testWidgets('${entry.key.name} draws three lines ${entry.value} apart', (
        tester,
      ) async {
        await pumpGlyph(tester, ReaderLineSpacingGlyph(entry.key));
        expect(
          tester.getSize(find.byType(ReaderLineSpacingGlyph)),
          const Size.square(AppIconSize.sm),
        );
        final gap = entry.value;
        // Full-width lines centered on the 24-unit grid, in the icon stroke.
        expect(
          painterOf(ReaderLineSpacingGlyph),
          paints
            ..line(
              p1: Offset(4, 12 - gap),
              p2: Offset(20, 12 - gap),
              color: _ink,
              strokeWidth: 2,
            )
            ..line(p1: const Offset(4, 12), p2: const Offset(20, 12))
            ..line(p1: Offset(4, 12 + gap), p2: Offset(20, 12 + gap)),
        );
      });
    }

    test('gaps grow from Compact to Relaxed', () {
      expect(gaps.values.toList(), orderedEquals([4.0, 6.0, 8.0]));
    });

    testWidgets('inks with the ambient icon color and ignores direction', (
      tester,
    ) async {
      const selected = Color(0xFFAA0000);
      await pumpGlyph(
        tester,
        const ReaderLineSpacingGlyph(ReaderLineSpacingPreset.normal),
        direction: TextDirection.rtl,
        color: selected,
      );
      expect(
        painterOf(ReaderLineSpacingGlyph),
        paints..line(
          p1: const Offset(4, 6),
          p2: const Offset(20, 6),
          color: selected,
        ),
      );
      expect(
        find.descendant(
          of: find.byType(ReaderLineSpacingGlyph),
          matching: find.byWidgetPredicate((widget) => widget is Semantics),
        ),
        findsNothing,
      );
    });
  });

  group('ReaderMarginsGlyph', () {
    final halfLines = {
      ReaderMarginPreset.narrow: 4.5,
      ReaderMarginPreset.medium: 3.0,
      ReaderMarginPreset.wide: 1.5,
    };

    for (final entry in halfLines.entries) {
      testWidgets('${entry.key.name} draws a page with centered lines', (
        tester,
      ) async {
        await pumpGlyph(tester, ReaderMarginsGlyph(entry.key));
        expect(
          tester.getSize(find.byType(ReaderMarginsGlyph)),
          const Size.square(AppIconSize.sm),
        );
        final half = entry.value;
        expect(
          painterOf(ReaderMarginsGlyph),
          paints
            ..rrect(
              rrect: RRect.fromLTRBR(4, 2, 20, 22, const Radius.circular(2)),
              style: PaintingStyle.stroke,
              strokeWidth: 2,
              color: _ink,
            )
            ..line(p1: Offset(12 - half, 8), p2: Offset(12 + half, 8))
            ..line(p1: Offset(12 - half, 12), p2: Offset(12 + half, 12))
            ..line(
              p1: Offset(12 - half, 16),
              p2: Offset(12 + half, 16),
              color: _ink,
              strokeWidth: 2,
            ),
        );
      });
    }

    test('wider margins leave shorter lines inside the page', () {
      expect(halfLines.values.toList(), orderedEquals([4.5, 3.0, 1.5]));
      // The longest line keeps clear of the page stroke (inner edge at 5).
      expect(12 - halfLines[ReaderMarginPreset.narrow]! - 1, greaterThan(5));
    });

    testWidgets('inks with the ambient icon color in RTL', (tester) async {
      const disabled = Color(0x61000000);
      await pumpGlyph(
        tester,
        const ReaderMarginsGlyph(ReaderMarginPreset.wide),
        direction: TextDirection.rtl,
        color: disabled,
      );
      expect(
        painterOf(ReaderMarginsGlyph),
        paints
          ..rrect(color: disabled)
          ..line(
            p1: const Offset(10.5, 8),
            p2: const Offset(13.5, 8),
            color: disabled,
          ),
      );
    });
  });
}
