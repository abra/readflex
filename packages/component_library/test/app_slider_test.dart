import 'package:component_library/component_library.dart';
import 'package:cupertino_ui/cupertino_ui.dart' as cupertino;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final direction in TextDirection.values) {
    testWidgets('track taps seek across a nonunit range in $direction', (
      tester,
    ) async {
      var value = 20.0;
      final events = <(String, double)>[];
      await tester.pumpWidget(
        _SliderHost(
          direction: direction,
          child: StatefulBuilder(
            builder: (context, setState) => AppSlider(
              min: 10,
              max: 30,
              value: value,
              tapToSeek: true,
              onChangeStart: (next) => events.add(('start', next)),
              onChanged: (next) {
                events.add(('change', next));
                setState(() => value = next);
              },
              onChangeEnd: (next) => events.add(('end', next)),
            ),
          ),
        ),
      );
      final rect = tester.getRect(find.byType(cupertino.CupertinoSlider));
      const inset = 8 + cupertino.CupertinoThumbPainter.radius;
      for (final fraction in [0.0, .25, .75, 1.0]) {
        events.clear();
        final before = value;
        final visual = direction == TextDirection.rtl ? 1 - fraction : fraction;
        await tester.tapAt(
          Offset(
            rect.left + inset + visual * (rect.width - inset * 2),
            rect.center.dy,
          ),
        );
        await tester.pumpAndSettle();
        final expected = 10 + fraction * 20;
        expect(value, expected);
        expect(events, [
          ('start', before),
          ('change', expected),
          ('end', expected),
        ]);
      }
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  }

  testWidgets('track endpoints clamp and discrete track taps snap', (
    tester,
  ) async {
    var value = .5;
    await tester.pumpWidget(
      _SliderHost(
        child: StatefulBuilder(
          builder: (context, setState) => AppSlider(
            value: value,
            divisions: 4,
            tapToSeek: true,
            onChanged: (next) => setState(() => value = next),
          ),
        ),
      ),
    );
    final rect = tester.getRect(find.byType(cupertino.CupertinoSlider));
    for (final (x, expected) in [
      (rect.left + 1, 0.0),
      (rect.left + 22 + .3 * (rect.width - 44), .25),
      (rect.left + 22 + .68 * (rect.width - 44), .75),
      (rect.right - 1, 1.0),
    ]) {
      await tester.tapAt(Offset(x, rect.center.dy));
      await tester.pumpAndSettle();
      expect(value, expected);
    }
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('thumb drag retains native updates and completes exactly once', (
    tester,
  ) async {
    var value = .5;
    final events = <String>[];
    await tester.pumpWidget(
      _SliderHost(
        child: StatefulBuilder(
          builder: (context, setState) => AppSlider(
            value: value,
            tapToSeek: true,
            onChangeStart: (_) => events.add('start'),
            onChanged: (next) {
              events.add('change');
              setState(() => value = next);
            },
            onChangeEnd: (_) => events.add('end'),
          ),
        ),
      ),
    );
    await tester.dragFrom(
      tester.getCenter(find.byType(cupertino.CupertinoSlider)),
      const Offset(80, 0),
    );
    await tester.pumpAndSettle();
    expect(value, greaterThan(.5));
    expect(events.first, 'start');
    expect(events.last, 'end');
    expect(events.where((event) => event == 'start'), hasLength(1));
    expect(events.where((event) => event == 'end'), hasLength(1));
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('track scrolling cancels the tap without seeking', (
    tester,
  ) async {
    var commands = 0;
    await tester.pumpWidget(
      _SliderHost(
        child: AppSlider(
          value: .5,
          tapToSeek: true,
          onChanged: (_) => commands++,
        ),
      ),
    );
    final rect = tester.getRect(find.byType(cupertino.CupertinoSlider));
    await tester.dragFrom(
      rect.centerRight - const Offset(30, 0),
      const Offset(0, 80),
    );
    await tester.pumpAndSettle();
    expect(commands, 0);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('disabled track ignores taps and native adjustment semantics', (
    tester,
  ) async {
    var commands = 0;
    await tester.pumpWidget(
      _SliderHost(
        child: AppSlider(
          value: .5,
          tapToSeek: true,
          onChanged: null,
          onChangeStart: (_) => commands++,
          onChangeEnd: (_) => commands++,
        ),
      ),
    );
    final slider = find.byType(cupertino.CupertinoSlider);
    await tester.tapAt(
      tester.getRect(slider).centerRight - const Offset(22, 0),
    );
    await tester.dragFrom(tester.getCenter(slider), const Offset(80, 0));
    await tester.pumpAndSettle();
    expect(commands, 0);
    expect(
      tester
          .getSemantics(slider)
          .getSemanticsData()
          .hasAction(SemanticsAction.increase),
      isFalse,
    );
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets(
    'native adjustments remain accessible without a duplicate tap action',
    (
      tester,
    ) async {
      final values = <double>[];
      await tester.pumpWidget(
        _SliderHost(
          child: AppSlider(value: .5, tapToSeek: true, onChanged: values.add),
        ),
      );
      final node = tester.getSemantics(find.byType(cupertino.CupertinoSlider));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
      node.owner!.performAction(node.id, SemanticsAction.increase);
      await tester.pump();
      expect(values, [.6]);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('native track tapping remains opt in', (tester) async {
    var commands = 0;
    await tester.pumpWidget(
      _SliderHost(child: AppSlider(value: .5, onChanged: (_) => commands++)),
    );
    final rect = tester.getRect(find.byType(cupertino.CupertinoSlider));
    await tester.tapAt(rect.centerRight - const Offset(22, 0));
    await tester.pumpAndSettle();
    expect(commands, 0);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}

class _SliderHost extends StatelessWidget {
  const _SliderHost({required this.child, this.direction = TextDirection.ltr});

  final Widget child;
  final TextDirection direction;

  @override
  Widget build(BuildContext context) => cupertino.CupertinoApp(
    home: AppPlatformTheme(
      platform: TargetPlatform.iOS,
      brightness: Brightness.light,
      child: AppScaffold(
        body: Directionality(
          textDirection: direction,
          child: Center(child: SizedBox(width: 280, child: child)),
        ),
      ),
    ),
  );
}
