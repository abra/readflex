import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_webview/src/comic_touch_tap_forwarder.dart';

void main() {
  const point = Offset(150, 250);
  final taps = <Offset>[];

  Future<void> mount(WidgetTester tester) async {
    taps.clear();
    await tester.pumpWidget(
      Padding(
        padding: const EdgeInsets.only(left: 30, top: 50),
        child: ComicTouchTapForwarder(
          onTap: taps.add,
          child: const ColoredBox(color: Color(0xffcccccc)),
        ),
      ),
    );
  }

  testWidgets('forwards both rapid taps in local WebView coordinates', (
    tester,
  ) async {
    await mount(tester);
    for (var index = 0; index < 2; index++) {
      final gesture = await tester.startGesture(point);
      await gesture.up(timeStamp: const Duration(milliseconds: 50));
    }
    expect(taps, [const Offset(120, 200), const Offset(120, 200)]);
  });

  testWidgets('pan remains disqualified even after returning to its start', (
    tester,
  ) async {
    await mount(tester);
    final gesture = await tester.startGesture(point);
    await gesture.moveBy(const Offset(15, 0));
    await gesture.moveTo(point);
    await gesture.up();
    expect(taps, isEmpty);
  });

  testWidgets('long press and cancelled touches are not taps', (tester) async {
    await mount(tester);
    final held = await tester.startGesture(point);
    await held.up(timeStamp: const Duration(milliseconds: 280));
    final cancelled = await tester.startGesture(point);
    await cancelled.cancel();
    expect(taps, isEmpty);
    await tester.tapAt(point);
    expect(taps, hasLength(1));
  });

  testWidgets('pinch does not turn into a tap as fingers lift', (tester) async {
    await mount(tester);
    final first = await tester.startGesture(point, pointer: 1);
    final second = await tester.startGesture(
      point + const Offset(40, 0),
      pointer: 2,
    );
    await first.up();
    await second.up();
    expect(taps, isEmpty);
    await tester.tapAt(point);
    expect(taps, hasLength(1));
  });

  testWidgets('mouse taps stay with the DOM click handler', (tester) async {
    await mount(tester);
    final mouse = await tester.startGesture(
      point,
      kind: PointerDeviceKind.mouse,
    );
    await mouse.up();
    expect(taps, isEmpty);
  });

  testWidgets('backgrounding cancels an incomplete touch', (tester) async {
    await mount(tester);
    final gesture = await tester.startGesture(point);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await gesture.up();
    expect(taps, isEmpty);
    await tester.tapAt(point);
    expect(taps, hasLength(1));
  });
}
