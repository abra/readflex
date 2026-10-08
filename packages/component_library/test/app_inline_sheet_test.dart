import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _phone = Size(390, 844);
const _statusBar = 47.0;
const _homeIndicator = 34.0;
const _keyboard = 291.0;

/// Full: 844 - 47 status bar - 8 gap. Half: 60% of that.
const _fullHeight = 789.0;
const _halfHeight = 473.4;

void main() {
  _geometryTests();

  group('AppInlineSheet', () {
    testWidgets('a hidden sheet is offstage with no scrim or semantics', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pumpHost(tester);

      expect(_barrier, findsNothing);
      expect(
        tester.widget<Offstage>(_offstageFinder).offstage,
        isTrue,
      );
      expect(find.bySemanticsLabel('Contents'), findsNothing);
      semantics.dispose();
    });

    testWidgets('opens at 60% of the height below the status bar', (
      tester,
    ) async {
      await _pumpHost(tester);
      await _open(tester);

      final surface = tester.getRect(_surface);
      expect(surface.top, moreOrLessEquals(_phone.height - _halfHeight));
      expect(surface.bottom, _phone.height);
      expect(surface.width, _phone.width);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a tablet sheet is centered within 640dp', (tester) async {
      await _pumpHost(tester, size: const Size(1024, 1366));
      await _open(tester);

      final surface = tester.getRect(_surface);
      expect(surface.width, 640);
      expect(surface.center.dx, 512);
    });

    testWidgets('the scrim asks the owner to close and the owner closes it', (
      tester,
    ) async {
      final host = await _pumpHost(tester);
      await _open(tester);

      await tester.tapAt(const Offset(195, 120));
      await tester.pumpAndSettle();

      expect(host.closeRequests, 1);
      expect(tester.widget<Offstage>(_offstageFinder).offstage, isTrue);
      expect(_barrier, findsNothing);
    });

    testWidgets('the scrim names the sheet for assistive technology', (
      tester,
    ) async {
      await _pumpHost(tester);
      await _open(tester);

      final barrier = tester.widget<ModalBarrier>(_barrier);
      expect(barrier.semanticsLabel, isNotEmpty);
      expect(barrier.semanticsOnTapHint, contains('Contents'));
    });

    testWidgets('names itself like a route', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpHost(tester);
      await _open(tester);

      expect(
        tester.getSemantics(find.bySemanticsLabel('Contents')),
        matchesSemantics(
          label: 'Contents',
          scopesRoute: true,
          namesRoute: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets('dragging the header up grows it to below the status bar', (
      tester,
    ) async {
      await _pumpHost(tester);
      await _open(tester);

      await tester.drag(find.text('Header'), const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(
        tester.getRect(_surface).top,
        moreOrLessEquals(_phone.height - _fullHeight),
      );
    });

    testWidgets('a fling down from full returns to half, then closes', (
      tester,
    ) async {
      final host = await _pumpHost(tester);
      await _open(tester);
      await tester.drag(find.text('Header'), const Offset(0, -300));
      await tester.pumpAndSettle();

      await tester.fling(find.text('Header'), const Offset(0, 120), 1500);
      await tester.pumpAndSettle();
      expect(
        tester.getRect(_surface).top,
        moreOrLessEquals(_phone.height - _halfHeight),
      );
      expect(host.closeRequests, 0);

      await tester.fling(find.text('Header'), const Offset(0, 120), 1500);
      await tester.pumpAndSettle();
      expect(host.closeRequests, 1);
      expect(tester.widget<Offstage>(_offstageFinder).offstage, isTrue);
    });

    testWidgets('a slow release keeps half unless dragged below its middle', (
      tester,
    ) async {
      final host = await _pumpHost(tester);
      await _open(tester);

      await _slowDrag(tester, find.text('Header'), 200);
      expect(host.closeRequests, 0);
      expect(
        tester.getRect(_surface).top,
        moreOrLessEquals(_phone.height - _halfHeight),
      );

      await _slowDrag(tester, find.text('Header'), 300);
      expect(host.closeRequests, 1);
    });

    testWidgets('an owner that keeps the sheet gets it back at half', (
      tester,
    ) async {
      final host = await _pumpHost(tester, ownerCloses: false);
      await _open(tester);

      await tester.fling(find.text('Header'), const Offset(0, 200), 1500);
      await tester.pumpAndSettle();

      expect(host.closeRequests, 1);
      expect(
        tester.getRect(_surface).top,
        moreOrLessEquals(_phone.height - _halfHeight),
      );
    });

    testWidgets('scrolling the list forward at half grows the sheet', (
      tester,
    ) async {
      await _pumpHost(tester);
      await _open(tester);

      await tester.drag(find.text('Row 2'), const Offset(0, -120));
      await tester.pumpAndSettle();

      expect(
        tester.getRect(_surface).top,
        moreOrLessEquals(_phone.height - _fullHeight),
      );
    });

    testWidgets(
      'pulling the list past its top steps down: full, half, closed',
      (tester) async {
        final host = await _pumpHost(tester);
        await _open(tester);
        await tester.drag(find.text('Header'), const Offset(0, -300));
        await tester.pumpAndSettle();

        await tester.drag(find.text('Row 1'), const Offset(0, 160));
        await tester.pumpAndSettle();
        expect(
          tester.getRect(_surface).top,
          moreOrLessEquals(_phone.height - _halfHeight),
        );

        await tester.drag(find.text('Row 1'), const Offset(0, 160));
        await tester.pumpAndSettle();
        expect(host.closeRequests, 1);
      },
      variant: const TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.iOS,
      }),
    );

    testWidgets('a short pull only scrolls the list back', (tester) async {
      final host = await _pumpHost(tester);
      await _open(tester);

      await tester.drag(find.text('Row 1'), const Offset(0, 30));
      await tester.pumpAndSettle();

      expect(host.closeRequests, 0);
      expect(
        tester.getRect(_surface).top,
        moreOrLessEquals(_phone.height - _halfHeight),
      );
    });

    testWidgets('a body with nothing to scroll drags like the header', (
      tester,
    ) async {
      final host = await _pumpHost(
        tester,
        body: const Center(child: Text('Nothing here')),
      );
      await _open(tester);

      await tester.fling(find.text('Nothing here'), const Offset(0, 200), 1500);
      await tester.pumpAndSettle();

      expect(host.closeRequests, 1);
    });

    testWidgets('sits on the keyboard and hides its inset from the body', (
      tester,
    ) async {
      final host = await _pumpHost(tester, body: const _InsetProbe());
      await _open(tester);
      expect(_InsetProbe.lastViewInset, 0);
      expect(_InsetProbe.lastBottomPadding, _homeIndicator);

      // The engine reports the safe inset as covered by the keyboard.
      tester.view
        ..viewInsets = const FakeViewPadding(bottom: _keyboard)
        ..padding = const FakeViewPadding(top: _statusBar);
      await tester.pumpAndSettle();

      final surface = tester.getRect(_surface);
      expect(surface.bottom, _phone.height - _keyboard);
      // 320dp floor: 60% of 498dp above the keyboard would be 298.8dp.
      expect(surface.height, moreOrLessEquals(320));
      expect(_InsetProbe.lastViewInset, 0);
      expect(_InsetProbe.lastBottomPadding, 0);
      expect(host.closeRequests, 0);
    });

    testWidgets('a centered sheet pads only for the cutout it reaches', (
      tester,
    ) async {
      await _pumpHost(
        tester,
        size: const Size(700, 390),
        topInset: 0,
        sideInsets: const (left: 44.0, right: 24.0),
        body: const _InsetProbe(),
      );
      await _open(tester);

      // 640dp sheet in 700dp: 30dp each side. The 44dp cutout reaches 14dp
      // into the sheet; the 24dp one does not reach it.
      final surface = tester.getRect(_surface);
      expect(surface.left, 30);
      expect(tester.getRect(find.text('Header')).left, 30 + 14);
      expect(_InsetProbe.lastSidePadding, EdgeInsets.zero);
    });

    testWidgets(
      'below its minimum the content scrolls as a whole and stays put',
      (tester) async {
        final host = await _pumpHost(tester, size: const Size(844, 390));
        tester.view
          ..viewInsets = const FakeViewPadding(bottom: 180)
          ..padding = const FakeViewPadding(top: _statusBar);
        await _open(tester);

        // 390 - 180 keyboard - 47 - 8 = 155dp, laid out at 320dp.
        final surface = tester.getRect(_surface);
        expect(surface.height, moreOrLessEquals(155));
        final header = tester.getRect(find.text('Header')).top;

        await tester.drag(find.text('Header'), const Offset(0, -100));
        await tester.pumpAndSettle();
        expect(tester.getRect(find.text('Header')).top, lessThan(header));
        expect(tester.getRect(_surface), surface);

        await tester.drag(find.text('Header'), const Offset(0, 300));
        await tester.pumpAndSettle();
        expect(host.closeRequests, 0);
        expect(tester.getRect(_surface), surface);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('crossing the minimum keeps the focused field alive', (
      tester,
    ) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await _pumpHost(
        tester,
        size: const Size(844, 390),
        body: Align(
          alignment: Alignment.topCenter,
          child: TextField(focusNode: focus),
        ),
      );
      await _open(tester);
      await tester.tap(find.byType(TextField));
      await tester.pump();
      final editable = tester.state(find.byType(EditableText));

      tester.view
        ..viewInsets = const FakeViewPadding(bottom: 180)
        ..padding = const FakeViewPadding(top: _statusBar);
      await tester.pumpAndSettle();

      expect(focus.hasFocus, isTrue);
      expect(tester.state(find.byType(EditableText)), same(editable));
      expect(tester.takeException(), isNull);
    });

    testWidgets('keeps body state while hidden', (tester) async {
      await _pumpHost(tester, body: const _CounterBody());
      await _open(tester);
      await tester.tap(find.text('Count 0'));
      await tester.pump();

      await tester.tapAt(const Offset(195, 120));
      await tester.pumpAndSettle();
      await _open(tester);

      expect(find.text('Count 1'), findsOneWidget);
    });

    testWidgets('a hidden sheet cannot take focus', (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await _pumpHost(tester, body: TextField(focusNode: focus));

      focus.requestFocus();
      await tester.pump();
      expect(focus.hasFocus, isFalse);

      await _open(tester);
      focus.requestFocus();
      await tester.pump();
      expect(focus.hasFocus, isTrue);
    });

    testWidgets('settles in one frame under reduced motion', (tester) async {
      final host = await _pumpHost(tester, disableAnimations: true);

      // Opened without a tap, so no button ink is left animating.
      host.open();
      await tester.pump();

      expect(
        tester.getRect(_surface).top,
        moreOrLessEquals(_phone.height - _halfHeight),
      );
      // A second frame without elapsed time: only focus bookkeeping from the
      // ExcludeFocus change was pending, a 300ms slide would still run.
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('a landscape phone opens straight to full', (tester) async {
      await _pumpHost(tester, size: const Size(844, 390), topInset: 0);
      await _open(tester);

      // A 320dp half of 382dp would leave too little to grow into.
      final top = tester.getRect(_surface).top;
      expect(top, moreOrLessEquals(AppInlineSheetGeometry.topGap));
      await tester.drag(find.text('Header'), const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(tester.getRect(_surface).top, top);
    });

    testWidgets('large text opens at full so rows stay in view', (
      tester,
    ) async {
      await _pumpHost(tester, textScale: 1.5);
      await _open(tester);

      expect(
        tester.getRect(_surface).top,
        moreOrLessEquals(_phone.height - _fullHeight),
      );
    });
  });
}

void _geometryTests() {
  group('AppInlineSheetGeometry', () {
    test('half is 60% of the space below the status bar', () {
      final geometry = AppInlineSheetGeometry.resolve(
        maxHeight: 844,
        keyboardInset: 0,
        topInset: _statusBar,
      );

      expect(geometry.full, _fullHeight);
      expect(geometry.half, moreOrLessEquals(_halfHeight));
      expect(geometry.canExpand, isTrue);
    });

    test('half never drops below 320dp', () {
      final geometry = AppInlineSheetGeometry.resolve(
        maxHeight: 844,
        keyboardInset: _keyboard,
        topInset: _statusBar,
      );

      expect(geometry.full, 498);
      expect(geometry.half, 320);
    });

    test('half and full merge when half would cover over 75% of full', () {
      final geometry = AppInlineSheetGeometry.resolve(
        maxHeight: 360,
        keyboardInset: 0,
        topInset: 0,
      );

      expect(geometry.full, 352);
      expect(geometry.half, 352);
      expect(geometry.canExpand, isFalse);
    });

    test('the half position grows with the text scale', () {
      AppInlineSheetGeometry at(double scale) => AppInlineSheetGeometry.resolve(
        maxHeight: 844,
        keyboardInset: 0,
        topInset: _statusBar,
        textScale: scale,
      );

      // 789 * 0.6 * 1.15 = 544.4dp still leaves room to grow.
      expect(at(1.15).half, moreOrLessEquals(544.41));
      expect(at(1.15).canExpand, isTrue);
      // 789 * 0.6 * 1.3 = 615.4dp is over 75% of 789dp: one position.
      expect(at(1.3).half, _fullHeight);
      expect(at(1.3).canExpand, isFalse);
      // Text smaller than default does not shrink the sheet.
      expect(at(0.85), at(1));
    });

    test('large text on a small phone opens at full without scrolling', () {
      final geometry = AppInlineSheetGeometry.resolve(
        maxHeight: 568,
        keyboardInset: 0,
        topInset: 0,
        textScale: 2,
      );

      expect(geometry.half, geometry.full);
      expect(geometry.scrollsContent, isFalse);
    });

    test(
      'above a keyboard on a short landscape screen the content scrolls',
      () {
        final geometry = AppInlineSheetGeometry.resolve(
          maxHeight: 390,
          keyboardInset: 180,
          topInset: _statusBar,
        );

        expect(geometry.full, 155);
        expect(geometry.half, 155);
        expect(geometry.scrollsContent, isTrue);
      },
    );

    test('no room leaves an empty sheet instead of a negative one', () {
      final geometry = AppInlineSheetGeometry.resolve(
        maxHeight: 200,
        keyboardInset: 300,
        topInset: 24,
      );

      expect(geometry.full, 0);
      expect(geometry.half, 0);
      expect(geometry.positionForExtent(40), AppInlineSheetPosition.closed);
    });

    test('opening slides a half-height sheet; growing changes its height', () {
      const geometry = AppInlineSheetGeometry(half: 400, full: 700);

      expect(geometry.heightAt(AppInlineSheetPosition.closed), 400);
      expect(geometry.slideAt(AppInlineSheetPosition.closed), 400);
      expect(geometry.heightAt(0.5), 400);
      expect(geometry.slideAt(0.5), 200);
      expect(geometry.slideAt(AppInlineSheetPosition.half), 0);
      expect(geometry.heightAt(1.5), 550);
      expect(geometry.slideAt(1.5), 0);
      expect(geometry.heightAt(AppInlineSheetPosition.full), 700);
    });

    test('extent and position round-trip across both segments', () {
      const geometry = AppInlineSheetGeometry(half: 400, full: 700);

      for (final position in [0.0, 0.25, 1.0, 1.4, 2.0]) {
        expect(
          geometry.positionForExtent(geometry.extentAt(position)),
          moreOrLessEquals(position),
        );
      }
      expect(geometry.positionForExtent(900), AppInlineSheetPosition.full);
    });

    test('a sheet without a full position stops at half', () {
      const geometry = AppInlineSheetGeometry(half: 352, full: 352);

      expect(geometry.positionForExtent(400), AppInlineSheetPosition.half);
    });
  });
}

final _sheet = find.byType(AppInlineSheet);
final _barrier = find.descendant(
  of: _sheet,
  matching: find.byType(ModalBarrier),
);
final _offstageFinder = find
    .descendant(of: _sheet, matching: find.byType(Offstage))
    .first;
final _surface = find
    .descendant(of: _sheet, matching: find.byType(Material))
    .first;

Future<_HostState> _pumpHost(
  WidgetTester tester, {
  Size size = _phone,
  double topInset = _statusBar,
  ({double left, double right}) sideInsets = (left: 0, right: 0),
  bool ownerCloses = true,
  bool disableAnimations = false,
  double textScale = 1,
  Widget? body,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1
    ..padding = FakeViewPadding(
      left: sideInsets.left,
      top: topInset,
      right: sideInsets.right,
      bottom: _homeIndicator,
    );
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: disableAnimations,
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: Scaffold(
        resizeToAvoidBottomInset: false,
        body: _Host(ownerCloses: ownerCloses, body: body),
      ),
    ),
  );
  return tester.state<_HostState>(find.byType(_Host));
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

/// Drags below the fling threshold so only the distance decides.
Future<void> _slowDrag(WidgetTester tester, Finder finder, double dy) async {
  final gesture = await tester.startGesture(tester.getCenter(finder));
  for (var moved = 0.0; moved < dy; moved += 20) {
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump(const Duration(milliseconds: 100));
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

class _Host extends StatefulWidget {
  const _Host({required this.ownerCloses, this.body});

  final bool ownerCloses;
  final Widget? body;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  var visible = false;
  var closeRequests = 0;

  void open() => setState(() => visible = true);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: TextButton(
            onPressed: open,
            child: const Text('Open'),
          ),
        ),
        Positioned.fill(
          child: AppInlineSheet(
            visible: visible,
            semanticsLabel: 'Contents',
            onClose: () {
              closeRequests++;
              if (widget.ownerCloses) setState(() => visible = false);
            },
            header: const SizedBox(height: 48, child: Text('Header')),
            body:
                widget.body ??
                ListView.builder(
                  itemCount: 40,
                  itemBuilder: (_, index) =>
                      SizedBox(height: 56, child: Text('Row $index')),
                ),
          ),
        ),
      ],
    );
  }
}

class _InsetProbe extends StatelessWidget {
  const _InsetProbe();

  static double? lastViewInset;
  static double? lastBottomPadding;
  static EdgeInsets? lastSidePadding;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    lastViewInset = MediaQuery.viewInsetsOf(context).bottom;
    lastBottomPadding = padding.bottom;
    lastSidePadding = EdgeInsets.only(left: padding.left, right: padding.right);
    return const SizedBox.expand();
  }
}

class _CounterBody extends StatefulWidget {
  const _CounterBody();

  @override
  State<_CounterBody> createState() => _CounterBodyState();
}

class _CounterBodyState extends State<_CounterBody> {
  var _count = 0;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: TextButton(
        onPressed: () => setState(() => _count++),
        child: Text('Count $_count'),
      ),
    );
  }
}
