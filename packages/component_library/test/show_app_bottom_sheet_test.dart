import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final closesFlow in [false, true]) {
    for (final color in [Colors.black54, Colors.transparent]) {
      testWidgets('scrim closesFlow=$closesFlow, color=$color', (tester) async {
        var blockedPops = 0;
        var hidden = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light().copyWith(
              bottomSheetTheme: BottomSheetThemeData(modalBarrierColor: color),
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showAppBottomSheet<void>(
                    context,
                    scrimClosesFlow: closesFlow,
                    onFullyHidden: () => hidden++,
                    builder: (_) => PopScope(
                      canPop: false,
                      onPopInvokedWithResult: (didPop, _) {
                        if (!didPop) blockedPops++;
                      },
                      child: const SizedBox(
                        height: 150,
                        child: Text('Content'),
                      ),
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        // System Back still belongs to the flow, regardless of scrim policy.
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(blockedPops, 1);
        expect(find.byType(BottomSheet), findsOneWidget);
        final barrier = tester.widget<ModalBarrier>(
          find.byType(ModalBarrier).last,
        );
        expect(barrier.semanticsLabel, isNotEmpty);
        expect(barrier.semanticsOnTapHint, isNotEmpty);
        expect(barrier.clipDetailsNotifier, isNotNull);
        await tester.tapAt(const Offset(10, 20));
        await tester.pumpAndSettle();
        expect(blockedPops, closesFlow ? 1 : 2);
        expect(hidden, closesFlow ? 1 : 0);
        expect(
          find.byType(BottomSheet),
          closesFlow ? findsNothing : findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
