import 'package:component_library/component_library.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final preference in [
    (
      name: 'Android Remove animations',
      platform: TargetPlatform.android,
      features: const FakeAccessibilityFeatures(disableAnimations: true),
    ),
    (
      name: 'iOS Reduce Motion',
      platform: TargetPlatform.iOS,
      features: const FakeAccessibilityFeatures(reduceMotion: true),
    ),
  ]) {
    for (final exit in ['command', 'scrim', 'system Back']) {
      testWidgets(
        '${preference.name} opens and closes at rest through $exit',
        (tester) async {
          tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
              preference.features;
          addTearDown(
            tester
                .binding
                .platformDispatcher
                .clearAccessibilityFeaturesTestValue,
          );
          var hidden = 0;
          final results = <String?>[];
          await tester.pumpWidget(
            _MotionSheetFixture(
              onFullyHidden: () => hidden++,
              onResult: results.add,
            ),
          );
          final media = MediaQuery.of(tester.element(find.byType(Scaffold)));
          expect(
            media.disableAnimations,
            preference.features.disableAnimations,
          );
          expect(media.reduceMotion, preference.features.reduceMotion);
          expect(
            tester.binding.disableAnimations,
            preference.features.disableAnimations,
          );
          await tester.tap(find.text('Open sheet'));
          await tester.pump();
          final controller = tester
              .widget<BottomSheet>(find.byType(BottomSheet))
              .animationController!;
          final openingStatus = controller.status;
          final openingBounds = tester.getRect(find.byType(BottomSheet));
          await tester.pumpAndSettle();
          final settledBounds = tester.getRect(find.byType(BottomSheet));
          expect(hidden, 0);
          expect(results, isEmpty);
          switch (exit) {
            case 'command':
              await tester.tap(find.text('Close sheet'));
            case 'scrim':
              await tester.tapAt(const Offset(10, 20));
            case 'system Back':
              await tester.binding.handlePopRoute();
          }
          await tester.pump();
          final hiddenAfterFirstFrame = hidden;
          final sheetRemains = find.byType(BottomSheet).evaluate().isNotEmpty;
          await tester.pumpAndSettle();
          expect(hidden, 1);
          expect(results, [exit == 'command' ? 'saved' : null]);
          expect(tester.takeException(), isNull);
          expect(openingStatus, AnimationStatus.completed);
          expect(openingBounds, settledBounds);
          expect(hiddenAfterFirstFrame, 1);
          expect(sheetRemains, isFalse);
        },
        variant: TargetPlatformVariant.only(preference.platform),
      );
    }
  }

  testWidgets('instant sheet can close before its first paint', (tester) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const Scaffold()),
    );
    final context = tester.element(find.byType(Scaffold));
    var hidden = 0;
    final result = showAppBottomSheet<String>(
      context,
      onFullyHidden: () => hidden++,
      builder: (_) => const SizedBox(height: 160),
    );
    Navigator.of(context).pop('saved');
    await tester.pumpAndSettle();
    expect(await result, 'saved');
    expect(hidden, 1);
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ordinary sheets keep their enter and exit transitions', (
    tester,
  ) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures();
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );
    var hidden = 0;
    final results = <String?>[];
    await tester.pumpWidget(
      _MotionSheetFixture(onFullyHidden: () => hidden++, onResult: results.add),
    );
    await tester.tap(find.text('Open sheet'));
    await tester.pump();
    final controller = tester
        .widget<BottomSheet>(find.byType(BottomSheet))
        .animationController!;
    expect(controller.status, AnimationStatus.forward);
    await tester.pumpAndSettle();
    expect(hidden, 0);
    await tester.tap(find.text('Close sheet'));
    await tester.pump();
    expect(controller.status, AnimationStatus.reverse);
    expect(hidden, 0);
    await tester.pumpAndSettle();
    expect(hidden, 1);
    expect(results, ['saved']);
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

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

class _MotionSheetFixture extends StatelessWidget {
  const _MotionSheetFixture({
    required this.onFullyHidden,
    required this.onResult,
  });

  final VoidCallback onFullyHidden;
  final ValueChanged<String?> onResult;

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: AppTheme.light(),
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () async {
            final result = await showAppBottomSheet<String>(
              context,
              onFullyHidden: onFullyHidden,
              builder: (context) => SizedBox(
                height: 160,
                child: Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop('saved'),
                    child: const Text('Close sheet'),
                  ),
                ),
              ),
            );
            onResult(result);
          },
          child: const Text('Open sheet'),
        ),
      ),
    ),
  );
}
