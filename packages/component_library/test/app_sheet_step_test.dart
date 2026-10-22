import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const stepKey = Key('step-content');

  Widget host(
    Widget step, {
    TextDirection ambient = TextDirection.ltr,
  }) => MaterialApp(
    home: Directionality(
      textDirection: ambient,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 100, height: 50, child: step),
      ),
    ),
  );

  group('reachability', () {
    late FocusNode focus;
    late int taps;
    late bool tickersEnabled;

    setUp(() {
      focus = FocusNode();
      taps = 0;
    });
    tearDown(() => focus.dispose());

    Widget probe() => Focus(
      focusNode: focus,
      child: Builder(
        builder: (context) {
          tickersEnabled = TickerMode.valuesOf(context).enabled;
          return GestureDetector(
            key: stepKey,
            behavior: HitTestBehavior.opaque,
            onTap: () => taps++,
            child: Semantics(label: 'Step action', child: const SizedBox()),
          );
        },
      ),
    );

    testWidgets('an active step takes semantics, focus, taps and tickers', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        host(
          AppSheetStep(
            active: true,
            visible: true,
            position: const AlwaysStoppedAnimation(Offset.zero),
            child: probe(),
          ),
        ),
      );

      expect(find.bySemanticsLabel('Step action'), findsOneWidget);
      focus.requestFocus();
      await tester.pump();
      expect(focus.hasFocus, isTrue);
      await tester.tap(find.byKey(stepKey));
      expect(taps, 1);
      expect(tickersEnabled, isTrue);
      semantics.dispose();
    });

    testWidgets('an inactive step leaves them to the active one', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        host(
          AppSheetStep(
            active: false,
            visible: true,
            position: const AlwaysStoppedAnimation(Offset.zero),
            child: probe(),
          ),
        ),
      );

      expect(find.bySemanticsLabel('Step action'), findsNothing);
      focus.requestFocus();
      await tester.pump();
      expect(focus.hasFocus, isFalse);
      await tester.tap(find.byKey(stepKey), warnIfMissed: false);
      expect(taps, 0);
      expect(tickersEnabled, isFalse);
      semantics.dispose();
    });
  });

  testWidgets('a hidden step stays laid out offstage', (tester) async {
    await tester.pumpWidget(
      host(
        const AppSheetStep(
          active: false,
          visible: false,
          position: AlwaysStoppedAnimation(Offset.zero),
          child: SizedBox(key: stepKey),
        ),
      ),
    );

    expect(find.byKey(stepKey), findsNothing);
    expect(find.byKey(stepKey, skipOffstage: false), findsOneWidget);
    expect(
      tester.getSize(find.byKey(stepKey, skipOffstage: false)),
      const Size(100, 50),
    );
  });

  testWidgets('maintainSize keeps a hidden step sizing the flow', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: Stack(
            key: const Key('flow'),
            children: [
              AppSheetStep(
                active: false,
                visible: false,
                maintainSize: true,
                position: const AlwaysStoppedAnimation(Offset.zero),
                child: GestureDetector(
                  key: stepKey,
                  behavior: HitTestBehavior.opaque,
                  onTap: () => taps++,
                  child: const SizedBox(width: 80, height: 120),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byKey(const Key('flow'))), const Size(80, 120));
    expect(find.byKey(stepKey), findsOneWidget);
    await tester.tap(find.byKey(stepKey), warnIfMissed: false);
    expect(taps, 0);
  });

  group('slide direction', () {
    Future<double> slidLeft(
      WidgetTester tester, {
      required TextDirection ambient,
      TextDirection? captured,
    }) async {
      await tester.pumpWidget(
        host(
          AppSheetStep(
            active: true,
            visible: true,
            textDirection: captured,
            position: const AlwaysStoppedAnimation(Offset(1, 0)),
            child: const SizedBox.expand(key: stepKey),
          ),
          ambient: ambient,
        ),
      );
      return tester.getTopLeft(find.byKey(stepKey)).dx;
    }

    testWidgets('follows the ambient direction by default', (tester) async {
      expect(await slidLeft(tester, ambient: TextDirection.ltr), 100);
      expect(await slidLeft(tester, ambient: TextDirection.rtl), -100);
    });

    testWidgets('a captured direction wins over the ambient one', (
      tester,
    ) async {
      expect(
        await slidLeft(
          tester,
          ambient: TextDirection.rtl,
          captured: TextDirection.ltr,
        ),
        100,
      );
      expect(
        await slidLeft(
          tester,
          ambient: TextDirection.ltr,
          captured: TextDirection.rtl,
        ),
        -100,
      );
    });
  });
}
