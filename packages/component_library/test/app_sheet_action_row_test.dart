import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Copy action sits on the gutter, centered on the first line of its
/// text, with the same room around the text whether it wraps or not.
void main() {
  // The test font draws every glyph as a square of the font size; a line is
  // fontSize * height tall. A 24 px line leaves 12 px of the 48 px target on
  // either side.
  const lineStyle = TextStyle(fontSize: 20, height: 1.2, letterSpacing: 0);
  const leadStyle = TextStyle(fontSize: 20, height: 1, letterSpacing: 0);
  const bodyKey = ValueKey('body');
  const leadKey = ValueKey('lead');
  const actionKey = ValueKey('action');
  const rowWidth = 320.0;

  Future<void> pumpRow(
    WidgetTester tester, {
    String text = 'Word',
    TextStyle style = lineStyle,
    Widget? lead,
    double leadSpacing = AppSpacing.xs,
    double minTextRoom = 0,
    TextDirection ambient = TextDirection.ltr,
    TextDirection? textDirection,
    VoidCallback? onAction,
    double width = rowWidth,
  }) async {
    tester.view.physicalSize = Size(width, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Directionality(
          textDirection: ambient,
          child: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: AppSheetActionRow(
                firstLineStyle: style,
                textDirection: textDirection,
                lead: lead,
                leadSpacing: leadSpacing,
                minTextRoom: minTextRoom,
                action: GestureDetector(
                  key: actionKey,
                  behavior: HitTestBehavior.opaque,
                  onTap: onAction,
                  child: const SizedBox.square(dimension: 48),
                ),
                child: Text(text, key: bodyKey, style: style),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Rect rect(WidgetTester tester, Key key) => tester.getRect(find.byKey(key));
  Rect rowRect(WidgetTester tester) =>
      tester.getRect(find.byType(AppSheetActionRow));
  // The row's own layout, reached through its public widget.
  Finder layout() => find.descendant(
    of: find.byType(AppSheetActionRow),
    matching: find.byWidgetPredicate(
      (widget) => widget is SlottedMultiChildRenderObjectWidget,
    ),
  );
  RenderBox renderRow(WidgetTester tester) => tester.renderObject(layout());

  for (final direction in TextDirection.values) {
    testWidgets('sheet actions share the header gutter ($direction)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var copied = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Directionality(
            textDirection: direction,
            child: Scaffold(
              body: ActionBottomSheetLayout.scrollable(
                title: 'Definition',
                closeLabel: 'Close',
                onClose: () {},
                bodyPadding: EdgeInsets.zero,
                child: AppSheetActionRow(
                  firstLineStyle: lineStyle,
                  action: AppCopyButton(
                    onCopy: () async {
                      copied = true;
                    },
                    copyLabel: 'Copy',
                    copiedLabel: 'Copied',
                    failureLabel: 'Failed',
                  ),
                  child: const Text('Word', style: lineStyle),
                ),
              ),
            ),
          ),
        ),
      );
      final copy = find.widgetWithIcon(IconButton, AppIcons.copy);
      final close = find.widgetWithIcon(IconButton, AppIcons.close);
      expect(tester.getSize(copy), const Size.square(48));
      expect(tester.getRect(copy).center.dx, tester.getRect(close).center.dx);
      final icon = tester.getRect(find.byIcon(AppIcons.copy));
      expect(direction == TextDirection.ltr ? 320 - icon.right : icon.left, 24);
      final bounds = tester.getRect(copy);
      await tester.tapAt(
        Offset(
          direction == TextDirection.ltr ? bounds.right - 1 : bounds.left + 1,
          bounds.center.dy,
        ),
      );
      await tester.pump();
      expect(copied, isTrue);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a single line has the action centered on it ($direction)', (
      tester,
    ) async {
      await pumpRow(tester, textDirection: direction);
      final row = rowRect(tester);
      final body = rect(tester, bodyKey);
      final action = rect(tester, actionKey);
      expect(row.height, 48);
      expect(body.top - row.top, 12);
      expect(action.center.dy, body.top + 12);
      expect(row.bottom - body.bottom, 12);
      final ltr = direction == TextDirection.ltr;
      expect(ltr ? body.left : rowWidth - body.right, AppSpacing.xl);
      expect(
        ltr ? rowWidth - action.right : action.left,
        AppSpacing.xl - AppSizes.iconActionOutset,
      );
      expect(
        ltr ? action.left - body.right : body.left - action.right,
        moreOrLessEquals(0),
      );
    });
  }

  testWidgets('wrapped text keeps the action on its first line', (
    tester,
  ) async {
    await pumpRow(tester, text: List.filled(12, 'word').join(' '));
    final row = rowRect(tester);
    final body = rect(tester, bodyKey);
    final action = rect(tester, actionKey);
    expect(body.height, greaterThanOrEqualTo(3 * 24));
    expect(body.top - row.top, 12);
    expect(action.center.dy, body.top + 12);
    // Below the last line there is only the room asked for.
    expect(row.bottom, body.bottom);
  });

  testWidgets('a minimum text room as large as the action excess keeps the '
      'room when text wraps', (tester) async {
    for (final words in [1, 12]) {
      await pumpRow(
        tester,
        text: List.filled(words, 'word').join(' '),
        minTextRoom: 12,
      );
      final row = rowRect(tester);
      final body = rect(tester, bodyKey);
      expect(body.top - row.top, 12, reason: '$words words');
      expect(row.bottom - body.bottom, 12, reason: '$words words');
    }
  });

  testWidgets('lead text moves the action down instead of the text', (
    tester,
  ) async {
    await pumpRow(
      tester,
      lead: const Text('Lead', key: leadKey, style: leadStyle),
    );
    final row = rowRect(tester);
    final lead = rect(tester, leadKey);
    final body = rect(tester, bodyKey);
    final action = rect(tester, actionKey);
    expect(lead.top, row.top);
    expect(body.top - lead.bottom, AppSpacing.xs);
    expect(action.center.dy, body.top + 12);
    expect(row.bottom, action.bottom);
  });

  testWidgets('a short lead keeps the action inside the row', (tester) async {
    // Lead and spacing together are shorter than half the target's excess:
    // the row still starts at the action's top.
    await pumpRow(
      tester,
      lead: const SizedBox(key: leadKey, height: 4),
      leadSpacing: 0,
    );
    final row = rowRect(tester);
    final body = rect(tester, bodyKey);
    final action = rect(tester, actionKey);
    expect(action.top, row.top);
    expect(body.top - row.top, 12);
    expect(rect(tester, leadKey).bottom, body.top);
  });

  testWidgets('a custom lead spacing separates a caption from its answer', (
    tester,
  ) async {
    await pumpRow(
      tester,
      lead: const Text('Caption', key: leadKey, style: leadStyle),
      leadSpacing: AppSpacing.sm,
    );
    expect(
      rect(tester, bodyKey).top - rect(tester, leadKey).bottom,
      AppSpacing.sm,
    );
  });

  for (final direction in TextDirection.values) {
    testWidgets('the lead spans both content edges; the text stops at the '
        'action ($direction)', (tester) async {
      await pumpRow(
        tester,
        textDirection: direction,
        lead: const SizedBox(key: leadKey, height: 20),
      );
      final lead = rect(tester, leadKey);
      final body = rect(tester, bodyKey);
      expect(lead.left, AppSpacing.xl);
      expect(lead.right, rowWidth - AppSpacing.xl);
      expect(
        body.width,
        AppSheetActionRow.childWidthFor(rowWidth),
        reason: 'the body never runs under the action',
      );
    });
  }

  testWidgets('the lead keeps the ambient direction; the action follows the '
      'text', (tester) async {
    await pumpRow(
      tester,
      ambient: TextDirection.rtl,
      textDirection: TextDirection.ltr,
      lead: const Text('Caption', key: leadKey, style: leadStyle),
    );
    expect(
      Directionality.of(tester.element(find.byKey(leadKey))),
      TextDirection.rtl,
    );
    expect(
      Directionality.of(tester.element(find.byKey(bodyKey))),
      TextDirection.ltr,
    );
    // LTR text in an RTL interface: Copy trails it on the right.
    expect(
      rect(tester, actionKey).left,
      greaterThanOrEqualTo(rect(tester, bodyKey).right - 1),
    );
  });

  testWidgets('a minimum text room holds above and below when the action '
      'leaves less', (tester) async {
    // 12 px of the action's excess is on either side; 16 px is asked for.
    await pumpRow(tester, minTextRoom: 16);
    var row = rowRect(tester);
    var body = rect(tester, bodyKey);
    expect(body.top - row.top, 16);
    expect(rect(tester, actionKey).center.dy, body.top + 12);
    expect(row.bottom - body.bottom, 16);
    // Less than the excess changes nothing.
    await pumpRow(tester, minTextRoom: 8);
    row = rowRect(tester);
    body = rect(tester, bodyKey);
    expect(body.top - row.top, 12);
    expect(row.bottom - body.bottom, 12);
    // It applies above a lead as well.
    await pumpRow(
      tester,
      minTextRoom: 16,
      lead: const Text('Lead', key: leadKey, style: leadStyle),
    );
    expect(rect(tester, leadKey).top - rowRect(tester).top, 16);
  });

  testWidgets('a minimum text room keeps gaps for lines taller than the '
      'action', (tester) async {
    const tall = TextStyle(fontSize: 30, height: 2, letterSpacing: 0);
    await pumpRow(tester, style: tall, minTextRoom: 12);
    final row = rowRect(tester);
    final body = rect(tester, bodyKey);
    expect(body.top - row.top, 12);
    expect(row.bottom - body.bottom, 12);
    expect(rect(tester, actionKey).center.dy, body.top + 30);
  });

  testWidgets('a line taller than the action adds no room', (tester) async {
    const tall = TextStyle(fontSize: 30, height: 2, letterSpacing: 0);
    await pumpRow(tester, style: tall);
    final row = rowRect(tester);
    final body = rect(tester, bodyKey);
    expect(body.top, row.top);
    expect(body.bottom, row.bottom);
    expect(rect(tester, actionKey).center.dy, body.top + 30);
  });

  testWidgets('without a line height the font metrics give the line', (
    tester,
  ) async {
    const metricsOnly = TextStyle(fontSize: 20, letterSpacing: 0);
    await pumpRow(tester, style: metricsOnly);
    final body = rect(tester, bodyKey);
    // A single line without a height multiple is as tall as the font's
    // line; the action is centered on it.
    expect(rect(tester, actionKey).center.dy, body.center.dy);
  });

  testWidgets('the line follows the text scale', (tester) async {
    tester.view.physicalSize = const Size(rowWidth, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: AppSheetActionRow(
                firstLineStyle: lineStyle,
                action: const SizedBox(key: actionKey, width: 48, height: 48),
                child: const Text('Word', key: bodyKey, style: lineStyle),
              ),
            ),
          ),
        ),
      ),
    );
    // A 2x line is 48 px, as tall as the action: no excess around it.
    final body = rect(tester, bodyKey);
    expect(body.top, rowRect(tester).top);
    expect(rect(tester, actionKey).center.dy, body.top + 24);
  });

  testWidgets('the action takes taps over lead text; the lead elsewhere', (
    tester,
  ) async {
    var actionTaps = 0;
    var leadTaps = 0;
    await pumpRow(
      tester,
      onAction: () => actionTaps++,
      lead: GestureDetector(
        key: leadKey,
        behavior: HitTestBehavior.opaque,
        onTap: () => leadTaps++,
        child: const SizedBox(height: 30),
      ),
    );
    final action = rect(tester, actionKey);
    final lead = rect(tester, leadKey);
    expect(action.top, lessThan(lead.bottom), reason: 'they overlap');
    await tester.tapAt(Offset(action.center.dx, lead.bottom - 1));
    await tester.tapAt(Offset(lead.left + 1, lead.top + 1));
    await tester.pump();
    expect(actionTaps, 1);
    expect(leadTaps, 1);
  });

  testWidgets('intrinsics, dry layout and dry baseline match the layout', (
    tester,
  ) async {
    for (final lead in [null, const Text('Lead', style: leadStyle)]) {
      for (final width in [rowWidth, 200.0]) {
        await pumpRow(
          tester,
          width: width,
          lead: lead,
          text: List.filled(6, 'word').join(' '),
        );
        final row = renderRow(tester);
        final constraints = BoxConstraints.tightFor(width: row.size.width);
        final reason = 'width $width, lead ${lead != null}';
        expect(row.getDryLayout(constraints), row.size, reason: reason);
        expect(
          row.getMinIntrinsicHeight(row.size.width),
          row.size.height,
          reason: reason,
        );
        expect(
          row.getMaxIntrinsicHeight(row.size.width),
          row.size.height,
          reason: reason,
        );
        // The first line of text gives the baseline: the lead's when present.
        final first = lead == null
            ? rect(tester, bodyKey)
            : tester.getRect(find.text('Lead'));
        final top = first.top - tester.getTopLeft(layout()).dy;
        // 15 px ascent of a 20 px glyph, plus half the leading of a 24 px line.
        expect(
          row.getDryBaseline(constraints, TextBaseline.alphabetic),
          closeTo(top + (lead == null ? 2 + 15 : 15), 1e-6),
          reason: reason,
        );
      }
    }
    final row = renderRow(tester);
    expect(
      row.getMinIntrinsicWidth(double.infinity),
      greaterThanOrEqualTo(48 + 4 * 20),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a baseline row aligns with the first line of text', (
    tester,
  ) async {
    const refKey = ValueKey('ref');
    for (final lead in [null, const Text('Lead', style: leadStyle)]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                const Text(
                  'R',
                  key: refKey,
                  style: TextStyle(fontSize: 40, height: 1),
                ),
                Expanded(
                  child: AppSheetActionRow(
                    firstLineStyle: lineStyle,
                    lead: lead,
                    action: const SizedBox.square(dimension: 48),
                    child: const Text('Word', key: bodyKey, style: lineStyle),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      final refBaseline = tester.getRect(find.byKey(refKey)).top + 30;
      final firstLineTop = lead == null
          ? rect(tester, bodyKey).top + 2
          : tester.getRect(find.text('Lead')).top;
      expect(refBaseline, firstLineTop + 15, reason: 'lead ${lead != null}');
    }
  });
}
