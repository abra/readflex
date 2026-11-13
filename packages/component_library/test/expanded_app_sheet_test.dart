import 'package:component_library/component_library.dart';
import 'package:component_library/src/app_sheet_drag_handle.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_support/platform_test_app.dart';

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final presentation in AppSheetPresentation.values) {
      testWidgets('$platform $presentation placement and retained draft', (
        tester,
      ) async {
        tester.view
          ..devicePixelRatio = 1
          ..physicalSize = const Size(1024, 768);
        addTearDown(tester.view.reset);
        var mounts = 0;
        var blocked = 0;
        var hidden = 0;
        await tester.pumpWidget(
          PlatformTestApp(
            platform: platform,
            home: Builder(
              builder: (context) => AppButton(
                onPressed: () => showAppBottomSheet<void>(
                  context,
                  presentation: presentation,
                  onFullyHidden: () => hidden++,
                  builder: (_) => _Draft(
                    onMount: () => mounts++,
                    onDismissAttempt: () => blocked++,
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        final contextual = presentation == AppSheetPresentation.contextual;
        final surface = find.byWidgetPredicate(
          (widget) =>
              widget is AppSurface &&
              widget.role ==
                  (contextual
                      ? AppSurfaceRole.sidePanel
                      : AppSurfaceRole.modal),
        );
        final rect = tester.getRect(surface);
        expect(rect.width, contextual ? 420 : 540);
        if (contextual) {
          expect(rect.right, 1024);
          expect(rect.top, 0);
          expect(rect.bottom, 768);
        } else if (presentation == AppSheetPresentation.actions) {
          expect(rect.right, 1000);
          expect(rect.bottom, 744);
        } else {
          expect(rect.center, const Offset(512, 384));
        }
        expect(find.byType(AppSheetDragHandle), findsNothing);
        await tester.tap(find.text('Increment'));
        await tester.pump();
        await tester.tapAt(const Offset(8, 8));
        await tester.pumpAndSettle();
        expect(blocked, 1);
        expect(hidden, 0);
        tester.view.physicalSize = const Size(390, 844);
        await tester.pumpAndSettle();
        expect(mounts, 1);
        expect(find.text('Count 1'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        expect(hidden, 1);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('$platform keeps a focused draft through keyboard and resize', (
      tester,
    ) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(1024, 768)
        ..viewPadding = const FakeViewPadding(top: 24, bottom: 34)
        ..padding = const FakeViewPadding(top: 24, bottom: 34);
      addTearDown(tester.view.reset);
      final draftKey = GlobalKey<_EditableDraftState>();
      var mounts = 0;
      EdgeInsets? builderInsets;
      await tester.pumpWidget(
        PlatformTestApp(
          platform: platform,
          home: Builder(
            builder: (context) => AppButton(
              onPressed: () => showAppBottomSheet<void>(
                context,
                presentation: AppSheetPresentation.contextual,
                builder: (context) {
                  builderInsets = MediaQuery.viewInsetsOf(context);
                  return _EditableDraft(
                    key: draftKey,
                    onMount: () => mounts++,
                  );
                },
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final panel = find.byWidgetPredicate(
        (widget) =>
            widget is AppSurface && widget.role == AppSurfaceRole.sidePanel,
      );
      expect(tester.getRect(panel).top, 24);
      expect(tester.getRect(panel).bottom, 768);
      final state = draftKey.currentState!;
      await tester.showKeyboard(find.byType(EditableText));
      await tester.enterText(find.byType(EditableText), 'Retained draft text');
      state.controller.selection = const TextSelection(
        baseOffset: 9,
        extentOffset: 14,
      );
      final value = state.controller.value;
      tester.view
        ..viewInsets = const FakeViewPadding(bottom: 240)
        ..padding = const FakeViewPadding(top: 24);
      await tester.pumpAndSettle();
      expect(tester.getRect(panel).bottom, 528);
      expect(state.lastInsets, EdgeInsets.zero);
      expect(builderInsets, EdgeInsets.zero);
      expect(state.lastPadding, EdgeInsets.zero);

      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      expect(draftKey.currentState, same(state));
      expect(state.focus.hasFocus, isTrue);
      expect(state.controller.value, value);
      expect(tester.testTextInput.isVisible, isTrue);
      expect(state.lastInsets, EdgeInsets.zero);
      expect(builderInsets, EdgeInsets.zero);
      expect(
        tester.getRect(find.byType(_EditableDraft)).bottom,
        844 - 240 - (platform == TargetPlatform.iOS ? 8 : 16),
      );

      tester.view
        ..physicalSize = const Size(1024, 768)
        ..viewInsets = FakeViewPadding.zero
        ..padding = const FakeViewPadding(top: 24, bottom: 34);
      await tester.pumpAndSettle();
      expect(draftKey.currentState, same(state));
      expect(mounts, 1);
      expect(state.focus.hasFocus, isTrue);
      expect(state.controller.value, value);
      expect(tester.getRect(panel).bottom, 768);
      expect(state.lastPadding, EdgeInsets.zero);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Close draft'));
      await tester.pumpAndSettle();
      expect(find.byType(_EditableDraft), findsNothing);
      expect(tester.takeException(), isNull);
    });

    for (final reducedMotion in [false, true]) {
      testWidgets('$platform closes an expanded sheet during entry '
          'reducedMotion=$reducedMotion', (tester) async {
        tester.view
          ..devicePixelRatio = 1
          ..physicalSize = const Size(1024, 768);
        addTearDown(tester.view.reset);
        tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
            FakeAccessibilityFeatures(reduceMotion: reducedMotion);
        addTearDown(
          tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        await tester.pumpWidget(
          PlatformTestApp(
            platform: platform,
            home: const SizedBox(key: ValueKey('opener')),
          ),
        );
        final context = tester.element(find.byKey(const ValueKey('opener')));
        var hidden = 0;
        final result = showAppBottomSheet<String>(
          context,
          onFullyHidden: () => hidden++,
          builder: (_) => const SizedBox(height: 200),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 40));
        final surface = find.byWidgetPredicate(
          (widget) =>
              widget is AppSurface && widget.role == AppSurfaceRole.modal,
        );
        expect(surface, findsOneWidget);
        final route = ModalRoute.of(tester.element(surface))!;
        expect(
          route.animation!.status,
          reducedMotion ? AnimationStatus.completed : AnimationStatus.forward,
        );
        Navigator.of(context).pop('saved');
        await tester.pumpAndSettle();
        expect(await result, 'saved');
        expect(hidden, 1);
        expect(surface, findsNothing);
        await tester.pump(const Duration(seconds: 1));
        expect(hidden, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }
}

class _EditableDraft extends StatefulWidget {
  const _EditableDraft({required this.onMount, super.key});

  final VoidCallback onMount;

  @override
  State<_EditableDraft> createState() => _EditableDraftState();
}

class _EditableDraftState extends State<_EditableDraft> {
  final controller = TextEditingController();
  final focus = FocusNode();
  EdgeInsets? lastInsets;
  EdgeInsets? lastPadding;

  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  void dispose() {
    controller.dispose();
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    lastInsets = MediaQuery.viewInsetsOf(context);
    lastPadding = MediaQuery.paddingOf(context);
    return SizedBox(
      height: 200,
      child: Column(
        children: [
          AppTextField(controller: controller, focusNode: focus),
          AppButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close draft'),
          ),
        ],
      ),
    );
  }
}

class _Draft extends StatefulWidget {
  const _Draft({required this.onMount, required this.onDismissAttempt});

  final VoidCallback onMount;
  final VoidCallback onDismissAttempt;

  @override
  State<_Draft> createState() => _DraftState();
}

class _DraftState extends State<_Draft> {
  var count = 0;

  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  Widget build(BuildContext context) => AppSheetDismissGuard(
    enabled: true,
    onDismissAttempt: widget.onDismissAttempt,
    child: SizedBox(
      height: 240,
      child: Column(
        children: [
          Text('Count $count'),
          AppButton(
            onPressed: () => setState(() => count++),
            child: const Text('Increment'),
          ),
          AppButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    ),
  );
}
