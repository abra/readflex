import 'package:component_library/component_library.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('Cupertino scrim resolves its $brightness appearance', (
      tester,
    ) async {
      await tester.pumpWidget(_CupertinoSheetFixture(brightness: brightness));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final surface = find.byType(CupertinoPopupSurface);
      final route = ModalRoute.of(tester.element(surface))!;
      final expected = brightness == Brightness.dark
          ? const Color(0x7A000000)
          : const Color(0x33000000);
      expect(route.barrierColor, expected);
      expect(route.barrierColor, isNot(isA<CupertinoDynamicColor>()));
      final barrier = tester.widget<ModalBarrier>(
        find.byType(ModalBarrier).last,
      );
      expect(barrier.color, expected);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'Cupertino root uses content-sized popup and returns before hidden',
    (
      tester,
    ) async {
      var hidden = 0;
      final results = <String?>[];
      await tester.pumpWidget(
        _CupertinoSheetFixture(
          onHidden: () => hidden++,
          onResult: results.add,
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pump();
      final surface = find.byType(CupertinoPopupSurface);
      final route = ModalRoute.of(tester.element(surface))!;
      expect(route, isA<CupertinoModalPopupRoute<String>>());
      expect(route.animation!.status, AnimationStatus.forward);
      await tester.pumpAndSettle();
      expect(tester.getSize(surface).height, 160 + 20);
      expect(tester.getSize(surface).width, 540);
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(results, ['saved']);
      expect(hidden, 0);
      expect(route.animation!.status, AnimationStatus.reverse);
      await tester.pumpAndSettle();
      expect(hidden, 1);
      expect(surface, findsNothing);
      await tester.pump();
      expect(hidden, 1);
      expect(tester.takeException(), isNull);
    },
  );

  for (final flag in ['reduceMotion', 'disableAnimations']) {
    for (final exit in ['command', 'scrim', 'system Back']) {
      testWidgets('Cupertino $flag closes at rest through $exit', (
        tester,
      ) async {
        tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
            FakeAccessibilityFeatures(
              reduceMotion: flag == 'reduceMotion',
              disableAnimations: flag == 'disableAnimations',
            );
        addTearDown(
          tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        var hidden = 0;
        final results = <String?>[];
        await tester.pumpWidget(
          _CupertinoSheetFixture(
            onHidden: () => hidden++,
            onResult: results.add,
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pump();
        final surface = find.byType(CupertinoPopupSurface);
        final route = ModalRoute.of(tester.element(surface))!;
        expect(route.animation!.value, 1);
        final bounds = tester.getRect(surface);
        await tester.pumpAndSettle();
        expect(tester.getRect(surface), bounds);
        switch (exit) {
          case 'command':
            await tester.tap(find.text('Save'));
          case 'scrim':
            await tester.tapAt(const Offset(10, 20));
          case 'system Back':
            await tester.binding.handlePopRoute();
        }
        await tester.pump();
        expect(hidden, 1);
        expect(surface, findsNothing);
        expect(results, [exit == 'command' ? 'saved' : null]);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('Cupertino popup can close before first paint', (tester) async {
    await tester.pumpWidget(const _CupertinoSheetFixture());
    final context = tester.element(find.byKey(const ValueKey('opener')));
    var hidden = 0;
    final result = showAppBottomSheet<String>(
      context,
      onFullyHidden: () => hidden++,
      builder: (_) => const SizedBox(height: 120),
    );
    Navigator.of(context).pop('saved');
    await tester.pumpAndSettle();
    expect(await result, 'saved');
    expect(hidden, 1);
    expect(find.byType(CupertinoPopupSurface), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cupertino root popup captures themes from a nested navigator', (
    tester,
  ) async {
    await tester.pumpWidget(const _NestedCupertinoSheetFixture());
    final opener = tester.element(find.text('Open nested'));
    final root = Navigator.of(opener, rootNavigator: true);
    final nested = Navigator.of(opener);
    expect(nested, isNot(same(root)));
    await tester.tap(find.text('Open nested'));
    await tester.pumpAndSettle();
    final context = tester.element(find.text('Themed body'));
    expect(Navigator.of(context), same(root));
    expect(CupertinoTheme.of(context).brightness, Brightness.dark);
    expect(context.appTheme.colors.brightness, Brightness.dark);
    expect(context.isCupertino, isTrue);
    expect(ModalRoute.of(context)!.barrierColor, const Color(0x7A000000));
    expect(root.canPop(), isTrue);
    expect(nested.canPop(), isFalse);
    root.pop();
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoPopupSurface), findsNothing);
    expect(find.text('Open nested'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('non-dismissible Cupertino popup keeps system Back available', (
    tester,
  ) async {
    var hidden = 0;
    await tester.pumpWidget(
      _CupertinoSheetFixture(
        dismissible: false,
        onHidden: () => hidden++,
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final surface = find.byType(CupertinoPopupSurface);
    final before = tester.getRect(surface);
    await tester.tapAt(const Offset(10, 20));
    await tester.dragFrom(
      before.topCenter + const Offset(0, 10),
      const Offset(0, 400),
    );
    await tester.pumpAndSettle();
    expect(tester.getRect(surface), before);
    expect(hidden, 0);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(surface, findsNothing);
    expect(hidden, 1);
    expect(tester.takeException(), isNull);
  });

  for (final keyboard in [0.0, 300.0]) {
    testWidgets('Cupertino drag follows the finger with keyboard=$keyboard', (
      tester,
    ) async {
      await tester.pumpWidget(_CupertinoSheetFixture(keyboard: keyboard));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final surface = find.byType(CupertinoPopupSurface);
      final before = tester.getRect(surface);
      final gesture = await tester.startGesture(
        before.topCenter + const Offset(0, 10),
      );
      await gesture.moveBy(const Offset(0, 30));
      await tester.pump();
      final accepted = tester.getRect(surface);
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump();
      expect(tester.getRect(surface).top - accepted.top, closeTo(20, .01));
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(tester.getRect(surface), before);
      expect(
        Navigator.of(tester.element(surface)).userGestureInProgress,
        isFalse,
      );
      Navigator.of(tester.element(surface)).pop();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('slow drag dismisses a short sheet on a tall native phone', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(440, 956)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var hidden = 0;
    await tester.pumpWidget(
      _CupertinoSheetFixture(
        onHidden: () => hidden++,
        sheet: const SizedBox(height: 330, child: Text('Short menu')),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final surface = find.byType(CupertinoPopupSurface);
    expect(tester.getSize(surface).height, 350);
    await tester.timedDragFrom(
      tester.getTopLeft(surface) + const Offset(100, 10),
      const Offset(0, 350),
      const Duration(seconds: 2),
    );
    await tester.pumpAndSettle();
    expect(surface, findsNothing);
    expect(hidden, 1);
    expect(tester.takeException(), isNull);
  });

  for (final (distance, closes) in [(100.0, false), (190.0, true)]) {
    testWidgets(
      'slow drag $distance uses the visible sheet dismiss threshold',
      (
        tester,
      ) async {
        tester.view
          ..physicalSize = const Size(440, 956)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var hidden = 0;
        await tester.pumpWidget(
          _CupertinoSheetFixture(
            onHidden: () => hidden++,
            sheet: const SizedBox(height: 330, child: Text('Short menu')),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        final surface = find.byType(CupertinoPopupSurface);
        final before = tester.getRect(surface);
        expect(before.height, 350);
        await tester.timedDragFrom(
          before.topLeft + const Offset(100, 10),
          Offset(0, distance),
          const Duration(seconds: 2),
        );
        await tester.pumpAndSettle();
        if (closes) {
          expect(surface, findsNothing);
          expect(hidden, 1);
        } else {
          expect(tester.getRect(surface), before);
          expect(hidden, 0);
          Navigator.of(tester.element(surface)).pop();
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Cupertino guard blocks scrim/drag and retains body while toggled',
    (
      tester,
    ) async {
      var attempts = 0;
      var mounts = 0;
      var hidden = 0;
      await tester.pumpWidget(
        _CupertinoSheetFixture(
          onHidden: () => hidden++,
          sheet: _GuardedCupertinoBody(
            onMount: () => mounts++,
            onDismissAttempt: () => attempts++,
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Increment'));
      await tester.pump();
      expect(find.text('Count 1'), findsOneWidget);
      await tester.tapAt(const Offset(10, 20));
      await tester.pumpAndSettle();
      expect(attempts, 1);
      final surface = find.byType(CupertinoPopupSurface);
      final before = tester.getRect(surface);
      await tester.drag(find.text('Count 1'), const Offset(0, 400));
      await tester.pumpAndSettle();
      expect(tester.getRect(surface), before);
      expect(hidden, 0);
      await tester.tap(find.text('Toggle guard'));
      await tester.pumpAndSettle();
      expect(mounts, 1);
      expect(find.text('Count 1'), findsOneWidget);
      await tester.drag(find.text('Count 1'), const Offset(0, 400));
      await tester.pumpAndSettle();
      expect(surface, findsNothing);
      expect(hidden, 1);
      expect(attempts, 1);
      expect(tester.takeException(), isNull);
    },
  );

  for (final closesFlow in [false, true]) {
    testWidgets('Cupertino scrim closesFlow=$closesFlow keeps Back policy', (
      tester,
    ) async {
      var blocked = 0;
      await tester.pumpWidget(
        _CupertinoSheetFixture(
          scrimClosesFlow: closesFlow,
          sheet: PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) blocked++;
            },
            child: const SizedBox(height: 160, child: Text('Content')),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final surface = find.byType(CupertinoPopupSurface);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(blocked, 1);
      expect(surface, findsOneWidget);
      final barrier = tester.widget<ModalBarrier>(
        find.byType(ModalBarrier).last,
      );
      expect(barrier.semanticsLabel, isNotEmpty);
      await tester.tapAt(const Offset(10, 20));
      await tester.pumpAndSettle();
      expect(blocked, closesFlow ? 1 : 2);
      expect(surface, closesFlow ? findsNothing : findsOneWidget);
      if (!closesFlow) {
        Navigator.of(tester.element(surface)).pop();
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'Cupertino phone sheet handles keyboard, safe area and RTL text',
    (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        _CupertinoSheetFixture(
          keyboard: 300,
          textScale: 2,
          direction: TextDirection.rtl,
          sheet: SizedBox(
            height: 1200,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (var i = 0; i < 30; i++) const Text('مرحبا بالعالم'),
                  const Text('Last row'),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final surface = tester.getRect(find.byType(CupertinoPopupSurface));
      expect(surface.width, 374);
      expect(surface.bottom, closeTo(844 - 300 - 8, .01));
      expect(surface.top, greaterThanOrEqualTo(24));
      final body = tester.element(find.text('مرحبا بالعالم').first);
      expect(Directionality.of(body), TextDirection.rtl);
      await tester.scrollUntilVisible(find.text('Last row'), 160);
      expect(find.text('Last row').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      Navigator.of(body).pop();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('Cupertino popup stays bounded and keeps state after resize', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1032, 1376);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    var mounts = 0;
    await tester.pumpWidget(
      _CupertinoSheetFixture(
        sheet: _GuardedCupertinoBody(
          onMount: () => mounts++,
          onDismissAttempt: () {},
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final modal = find.byWidgetPredicate(
      (widget) => widget is AppSurface && widget.role == AppSurfaceRole.modal,
    );
    expect(tester.getSize(modal).width, 540);
    expect(tester.getRect(modal).center, const Offset(516, 683));
    await tester.tap(find.text('Increment'));
    await tester.pump();
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(CupertinoPopupSurface)).width, 374);
    expect(mounts, 1);
    expect(find.text('Count 1'), findsOneWidget);
    Navigator.of(tester.element(find.byType(CupertinoPopupSurface))).pop();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

class _NestedCupertinoSheetFixture extends StatelessWidget {
  const _NestedCupertinoSheetFixture();

  @override
  Widget build(BuildContext context) {
    final root = AppTheme.forPlatform(TargetPlatform.iOS, Brightness.light);
    final local = AppTheme.forPlatform(TargetPlatform.iOS, Brightness.dark);
    return CupertinoApp(
      theme: AppTheme.cupertino(root),
      builder: (context, child) => AppThemeScope(
        data: AppTheme.dataFor(root),
        child: child!,
      ),
      home: AppThemeScope(
        data: AppTheme.dataFor(local),
        child: CupertinoTheme(
          data: AppTheme.cupertino(local),
          child: Navigator(
            onGenerateRoute: (_) => CupertinoPageRoute<void>(
              builder: (context) => CupertinoPageScaffold(
                child: Center(
                  child: CupertinoButton(
                    onPressed: () => showAppBottomSheet<void>(
                      context,
                      builder: (_) => const SizedBox(
                        height: 160,
                        child: Text('Themed body'),
                      ),
                    ),
                    child: const Text('Open nested'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CupertinoSheetFixture extends StatelessWidget {
  const _CupertinoSheetFixture({
    this.onHidden,
    this.onResult,
    this.sheet,
    this.dismissible = true,
    this.scrimClosesFlow = false,
    this.keyboard = 0,
    this.textScale = 1,
    this.direction = TextDirection.ltr,
    this.brightness = Brightness.light,
  });

  final VoidCallback? onHidden;
  final ValueChanged<String?>? onResult;
  final Widget? sheet;
  final bool dismissible;
  final bool scrimClosesFlow;
  final double keyboard;
  final double textScale;
  final TextDirection direction;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    final adapter = AppTheme.forPlatform(TargetPlatform.iOS, brightness);
    return CupertinoApp(
      theme: AppTheme.cupertino(adapter),
      builder: (context, child) => AppThemeScope(
        data: AppTheme.dataFor(adapter),
        child: Directionality(
          textDirection: direction,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              padding: EdgeInsets.only(top: 24, bottom: keyboard == 0 ? 34 : 0),
              viewPadding: const EdgeInsets.only(top: 24, bottom: 34),
              viewInsets: EdgeInsets.only(bottom: keyboard),
            ),
            child: child!,
          ),
        ),
      ),
      home: CupertinoPageScaffold(
        child: Builder(
          builder: (context) => Center(
            child: CupertinoButton(
              key: const ValueKey('opener'),
              onPressed: () async {
                final result = await showAppBottomSheet<String>(
                  context,
                  dismissible: dismissible,
                  scrimClosesFlow: scrimClosesFlow,
                  onFullyHidden: onHidden,
                  builder: (context) =>
                      sheet ??
                      SizedBox(
                        height: 160,
                        child: Center(
                          child: CupertinoButton(
                            onPressed: () => Navigator.of(context).pop('saved'),
                            child: const Text('Save'),
                          ),
                        ),
                      ),
                );
                onResult?.call(result);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
  }
}

class _GuardedCupertinoBody extends StatefulWidget {
  const _GuardedCupertinoBody({
    required this.onMount,
    required this.onDismissAttempt,
  });

  final VoidCallback onMount;
  final VoidCallback onDismissAttempt;

  @override
  State<_GuardedCupertinoBody> createState() => _GuardedCupertinoBodyState();
}

class _GuardedCupertinoBodyState extends State<_GuardedCupertinoBody> {
  var _guard = true;
  var _count = 0;

  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  Widget build(BuildContext context) => AppSheetDismissGuard(
    enabled: _guard,
    onDismissAttempt: widget.onDismissAttempt,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Count $_count'),
        CupertinoButton(
          onPressed: () => setState(() => _count++),
          child: const Text('Increment'),
        ),
        CupertinoButton(
          onPressed: () => setState(() => _guard = !_guard),
          child: const Text('Toggle guard'),
        ),
      ],
    ),
  );
}
