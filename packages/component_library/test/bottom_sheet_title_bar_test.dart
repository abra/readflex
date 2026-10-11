import 'package:component_library/component_library.dart';
import 'package:component_library/src/bottom_sheet_title_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// The title keeps its action beside it by shrinking, down to the minimum
/// scale, and only then wraps the action below it, in either direction.
void main() {
  // The test font draws every glyph as a square of the font size: the
  // 10-glyph title is 200 px wide and 20 px tall, its baseline at 15 px.
  const title = 'Appearance';
  const titleStyle = TextStyle(fontSize: 20, height: 1, letterSpacing: 0);
  const naturalWidth = 200.0;
  const actionKey = ValueKey('action');
  const actionSize = Size(100, 48);
  const spacing = 12.0;
  const overflowSpacing = 4.0;
  const minTitleScale = 0.8;

  Future<RenderBottomSheetTitleBar> pumpBar(
    WidgetTester tester, {
    required double width,
    TextDirection direction = TextDirection.ltr,
    VoidCallback? onAction,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Directionality(
          textDirection: direction,
          child: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: BottomSheetTitleBar(
                  title: const Text(title, style: titleStyle),
                  trailing: GestureDetector(
                    key: actionKey,
                    behavior: HitTestBehavior.opaque,
                    onTap: onAction,
                    child: SizedBox.fromSize(size: actionSize),
                  ),
                  spacing: spacing,
                  overflowSpacing: overflowSpacing,
                  minTitleScale: minTitleScale,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return tester.renderObject(find.byType(BottomSheetTitleBar));
  }

  Rect titleRect(WidgetTester tester) => tester.getRect(find.text(title));
  Rect actionRect(WidgetTester tester) => tester.getRect(find.byKey(actionKey));
  Rect barRect(WidgetTester tester) =>
      tester.getRect(find.byType(BottomSheetTitleBar));

  for (final direction in TextDirection.values) {
    final ltr = direction == TextDirection.ltr;

    testWidgets('a title that fits keeps its size ($direction)', (
      tester,
    ) async {
      final bar = await pumpBar(tester, width: 400, direction: direction);
      final titleBox = titleRect(tester);
      final action = actionRect(tester);
      final row = barRect(tester);
      expect(bar.titleScale, 1);
      expect(titleBox.size, const Size(naturalWidth, 20));
      expect(row.height, actionSize.height);
      // Title on the start edge, action on the end edge, both centered.
      expect(ltr ? titleBox.left : titleBox.right, ltr ? row.left : row.right);
      expect(ltr ? action.right : action.left, ltr ? row.right : row.left);
      expect(titleBox.center.dy, row.center.dy);
      expect(action.center.dy, row.center.dy);
    });

    testWidgets('a long title shrinks just enough to keep the action '
        'beside it ($direction)', (tester) async {
      // 188 px of room for a 200 px title.
      const width = 300.0;
      final bar = await pumpBar(tester, width: width, direction: direction);
      const room = width - spacing - 100;
      final titleBox = titleRect(tester);
      final action = actionRect(tester);
      final row = barRect(tester);
      expect(bar.titleScale, closeTo(room / naturalWidth, 1e-9));
      expect(titleBox.width, closeTo(room, 1e-9));
      expect(titleBox.height, closeTo(20 * room / naturalWidth, 1e-9));
      expect(ltr ? titleBox.left : titleBox.right, ltr ? row.left : row.right);
      final gap = ltr
          ? action.left - titleBox.right
          : titleBox.left - action.right;
      expect(gap, closeTo(spacing, 1e-9));
      expect(titleBox.center.dy, closeTo(row.center.dy, 1e-9));
      expect(row.height, actionSize.height);
      // Shrunk when painted: the text keeps its style and its laid-out size.
      final paragraph = tester.renderObject<RenderParagraph>(find.text(title));
      expect(paragraph.size, const Size(naturalWidth, 20));
      expect(paragraph.text.style?.fontSize, 20);
    });

    testWidgets('a title too long for the minimum scale wraps the action '
        'below it ($direction)', (tester) async {
      // 148 px of room: below 0.8 of the 200 px title.
      final bar = await pumpBar(tester, width: 260, direction: direction);
      final titleBox = titleRect(tester);
      final action = actionRect(tester);
      final row = barRect(tester);
      expect(bar.titleScale, 1);
      expect(titleBox.size, const Size(naturalWidth, 20));
      expect(titleBox.top, row.top);
      expect(action.top, titleBox.bottom + overflowSpacing);
      expect(row.height, 20 + overflowSpacing + actionSize.height);
      // Both on the start edge.
      expect(ltr ? titleBox.left : titleBox.right, ltr ? row.left : row.right);
      expect(ltr ? action.left : action.right, ltr ? row.left : row.right);
    });
  }

  // Pixels, not rects: rects follow the paint transform the bar reports,
  // only the paint shows the transform is applied.
  testWidgets('a shrunk title paints like the title scaled at its place', (
    tester,
  ) async {
    const width = 300.0;
    const scale = (width - spacing - 100) / naturalWidth;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: RepaintBoundary(
              child: SizedBox(
                width: width,
                height: actionSize.height,
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      top: (actionSize.height - 20 * scale) / 2,
                      child: Transform.scale(
                        scale: scale,
                        alignment: Alignment.topLeft,
                        child: const Text(title, style: titleStyle),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final reference = await captureImage(
      tester.element(find.byType(RepaintBoundary).last),
    );
    addTearDown(reference.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: RepaintBoundary(
              child: SizedBox(
                width: width,
                child: BottomSheetTitleBar(
                  title: const Text(title, style: titleStyle),
                  trailing: SizedBox.fromSize(size: actionSize),
                  spacing: spacing,
                  overflowSpacing: overflowSpacing,
                  minTitleScale: minTitleScale,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await expectLater(
      find.byType(RepaintBoundary).last,
      matchesReferenceImage(reference),
    );
  });

  testWidgets('the shrink threshold is exactly the minimum scale', (
    tester,
  ) async {
    const atMinimum = naturalWidth * minTitleScale + spacing + 100;
    expect((await pumpBar(tester, width: atMinimum)).titleScale, minTitleScale);
    expect(actionRect(tester).top, barRect(tester).top);

    await pumpBar(tester, width: atMinimum - 1);
    expect(actionRect(tester).top, greaterThan(titleRect(tester).bottom));
  });

  testWidgets('the action takes taps in every layout', (tester) async {
    for (final width in [400.0, 300.0, 260.0]) {
      var taps = 0;
      await pumpBar(tester, width: width, onAction: () => taps++);
      await tester.tap(find.byKey(actionKey));
      // A tap on the title, scaled or not, is not the action's.
      await tester.tapAt(titleRect(tester).center);
      expect(taps, 1, reason: 'width $width');
    }
  });

  testWidgets('switching the direction mirrors a shrunk title', (
    tester,
  ) async {
    await pumpBar(tester, width: 300);
    final ltrTitle = titleRect(tester);
    await pumpBar(tester, width: 300, direction: TextDirection.rtl);
    final rtlTitle = titleRect(tester);
    expect(rtlTitle.right, barRect(tester).right);
    expect(rtlTitle.size, ltrTitle.size);
  });

  testWidgets('intrinsics, dry layout and dry baseline match the layout', (
    tester,
  ) async {
    for (final width in [400.0, 300.0, 260.0]) {
      final bar = await pumpBar(tester, width: width);
      final constraints = BoxConstraints.tightFor(width: width);
      expect(bar.getDryLayout(constraints), bar.size, reason: 'width $width');
      expect(bar.getMinIntrinsicHeight(width), bar.size.height);
      expect(bar.getMaxIntrinsicHeight(width), bar.size.height);
      final top = titleRect(tester).top - barRect(tester).top;
      expect(
        bar.getDryBaseline(constraints, TextBaseline.alphabetic),
        closeTo(top + 15 * bar.titleScale, 1e-9),
        reason: 'width $width',
      );
    }
    final bar = await pumpBar(tester, width: 400);
    expect(bar.getMaxIntrinsicWidth(double.infinity), naturalWidth + 112);
    expect(bar.getMinIntrinsicWidth(double.infinity), naturalWidth);
    expect(tester.takeException(), isNull);
  });

  group('with a compact action', () {
    const fullKey = ValueKey('full');
    const compactKey = ValueKey('compact');
    const fullColor = Color(0xFF00FF00);
    const compactColor = Color(0xFF0000FF);
    const compactSize = Size.square(48);

    late FocusNode fullFocus;
    late FocusNode compactFocus;
    setUp(() {
      fullFocus = FocusNode(debugLabel: 'full');
      compactFocus = FocusNode(debugLabel: 'compact');
    });
    tearDown(() {
      fullFocus.dispose();
      compactFocus.dispose();
    });

    Widget action({
      required Key key,
      required String label,
      required Color color,
      required Size size,
      required FocusNode focusNode,
      required VoidCallback onTap,
    }) => Semantics(
      key: key,
      button: true,
      label: label,
      child: Focus(
        focusNode: focusNode,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: ColoredBox(
            color: color,
            child: SizedBox.fromSize(size: size),
          ),
        ),
      ),
    );

    Future<RenderBottomSheetTitleBar> pumpBoth(
      WidgetTester tester, {
      required double width,
      TextDirection direction = TextDirection.ltr,
      List<String>? taps,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Directionality(
            textDirection: direction,
            child: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: width,
                  child: BottomSheetTitleBar(
                    title: const Text(title, style: titleStyle),
                    trailing: action(
                      key: fullKey,
                      label: 'Full',
                      color: fullColor,
                      size: actionSize,
                      focusNode: fullFocus,
                      onTap: () => taps?.add('full'),
                    ),
                    compactTrailing: action(
                      key: compactKey,
                      label: 'Compact',
                      color: compactColor,
                      size: compactSize,
                      focusNode: compactFocus,
                      onTap: () => taps?.add('compact'),
                    ),
                    spacing: spacing,
                    overflowSpacing: overflowSpacing,
                    minTitleScale: minTitleScale,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      // The hidden action leaves focus traversal after the frame.
      await tester.pump();
      return tester.renderObject(find.byType(BottomSheetTitleBar));
    }

    void expectShown(
      WidgetTester tester,
      RenderBottomSheetTitleBar bar, {
      required bool compact,
    }) {
      expect(bar.compactShown, compact);
      expect(
        bar,
        compact
            ? (paints..rect(color: compactColor))
            : (paints..rect(color: fullColor)),
      );
      expect(
        bar,
        isNot(
          compact
              ? (paints..rect(color: fullColor))
              : (paints..rect(color: compactColor)),
        ),
      );
      expect(
        find.byKey(compact ? compactKey : fullKey).hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byKey(compact ? fullKey : compactKey).hitTestable(),
        findsNothing,
      );
    }

    testWidgets('the full action stays while the title can shrink for it', (
      tester,
    ) async {
      // 168 px beside the full action: 0.84 of the title. The compact one
      // would leave the title whole, but the label wins.
      final bar = await pumpBoth(tester, width: 280);
      expectShown(tester, bar, compact: false);
      expect(bar.titleScale, closeTo(168 / naturalWidth, 1e-9));
    });

    for (final direction in TextDirection.values) {
      testWidgets('the compact action takes over below the minimum scale '
          '($direction)', (tester) async {
        // 108 px beside the full action, 160 px beside the compact one:
        // exactly the minimum scale.
        final bar = await pumpBoth(tester, width: 220, direction: direction);
        expectShown(tester, bar, compact: true);
        expect(bar.titleScale, closeTo(minTitleScale, 1e-9));
        final ltr = direction == TextDirection.ltr;
        final compact = tester.getRect(find.byKey(compactKey));
        final row = barRect(tester);
        expect(ltr ? compact.right : compact.left, ltr ? row.right : row.left);
        expect(compact.center.dy, row.center.dy);
        expect(row.height, actionSize.height);
        final gap = ltr
            ? compact.left - titleRect(tester).right
            : titleRect(tester).left - compact.right;
        expect(gap, closeTo(spacing, 1e-9));
      });
    }

    testWidgets('past the compact action the full one wraps below', (
      tester,
    ) async {
      final bar = await pumpBoth(tester, width: 200);
      expectShown(tester, bar, compact: false);
      expect(bar.titleScale, 1);
      expect(
        tester.getTopLeft(find.byKey(fullKey)).dy,
        titleRect(tester).bottom + overflowSpacing,
      );
    });

    testWidgets('only the shown action is tapped, announced and focused', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final taps = <String>[];
      await pumpBoth(tester, width: 220, taps: taps);
      await tester.tap(find.byKey(compactKey));
      expect(taps, ['compact']);
      expect(find.semantics.byLabel('Compact'), findsOneWidget);
      expect(find.semantics.byLabel('Full'), findsNothing);
      fullFocus.requestFocus();
      await tester.pump();
      expect(fullFocus.hasFocus, isFalse);
      compactFocus.requestFocus();
      await tester.pump();
      expect(compactFocus.hasFocus, isTrue);

      // Widening swaps them back; the focused compact action lets go.
      await pumpBoth(tester, width: 400, taps: taps);
      expect(compactFocus.hasFocus, isFalse);
      await tester.tap(find.byKey(fullKey));
      expect(taps, ['compact', 'full']);
      expect(find.semantics.byLabel('Full'), findsOneWidget);
      expect(find.semantics.byLabel('Compact'), findsNothing);
      fullFocus.requestFocus();
      await tester.pump();
      expect(fullFocus.hasFocus, isTrue);
      semantics.dispose();
    });

    testWidgets('intrinsics and dry layout follow the compact choice', (
      tester,
    ) async {
      for (final width in [280.0, 220.0, 200.0]) {
        final bar = await pumpBoth(tester, width: width);
        expect(
          bar.getDryLayout(BoxConstraints.tightFor(width: width)),
          bar.size,
          reason: 'width $width',
        );
        expect(bar.getMaxIntrinsicHeight(width), bar.size.height);
      }
    });
  });
}
