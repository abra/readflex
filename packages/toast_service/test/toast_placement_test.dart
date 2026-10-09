import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toast_service/toast_service.dart';
import 'package:toastification/toastification.dart';

const _screen = Size(390, 844);
final _toast = find.byType(BuiltInContainer);
final _bottomControl = find.byKey(const ValueKey('bottomControl'));

double _contrast(Color a, Color b) {
  final first = a.computeLuminance() + .05;
  final second = b.computeLuminance() + .05;
  return first > second ? first / second : second / first;
}

void main() {
  setUp(() => toastification.managers.clear());

  /// A page with an 80dp control [controlBottom] above the bottom edge,
  /// marked as a toast obstacle unless [avoid] is false.
  Future<BuildContext> pumpPage(
    WidgetTester tester, {
    double controlBottom = AppSpacing.lg,
    bool avoid = true,
    bool enabled = true,
    ThemeData? theme,
    VoidCallback? onControlPressed,
  }) async {
    tester.view.physicalSize = _screen;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late BuildContext context;
    final control = SizedBox(
      key: const ValueKey('bottomControl'),
      width: 240,
      height: 80,
      child: TextButton(
        onPressed: onControlPressed ?? () {},
        child: const Text('Control'),
      ),
    );
    await tester.pumpWidget(
      ToastWrapper(
        child: MaterialApp(
          theme: theme ?? AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Builder(
            builder: (value) {
              context = value;
              return Scaffold(
                body: Stack(
                  children: [
                    Positioned(
                      left: AppSpacing.lg,
                      bottom: controlBottom,
                      child: avoid
                          ? ToastAvoidArea(enabled: enabled, child: control)
                          : control,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return context;
  }

  Future<void> show(WidgetTester tester, BuildContext context) async {
    showToast(context, type: NotificationType.error, message: 'Not saved');
    await tester.pump();
    await tester.pumpAndSettle();
  }

  Future<void> dismiss(WidgetTester tester) async {
    toastification.dismissAll(delayForAnimation: false);
    await tester.pumpAndSettle();
  }

  testWidgets('with nothing to avoid a toast sits 16dp above the safe inset', (
    tester,
  ) async {
    final context = await pumpPage(tester, avoid: false);
    tester.view.viewPadding = const FakeViewPadding(bottom: 34);
    await tester.pumpAndSettle();
    await show(tester, context);
    expect(tester.getRect(_toast).bottom, _screen.height - 34 - AppSpacing.lg);
    await dismiss(tester);
  });

  for (final inset in [0.0, 34.0]) {
    testWidgets('a toast floats 8dp above a marked bottom control '
        '(inset $inset)', (tester) async {
      final context = await pumpPage(
        tester,
        controlBottom: inset + AppSpacing.lg + AppSpacing.sm,
      );
      tester.view.viewPadding = FakeViewPadding(bottom: inset);
      await tester.pumpAndSettle();
      await show(tester, context);
      final control = tester.getRect(_bottomControl);
      expect(
        tester.getRect(_toast).bottom,
        closeTo(control.top - AppSpacing.sm, .01),
      );
      await dismiss(tester);
    });
  }

  testWidgets('the overlay is lifted, not padded: the control under the '
      'toast stack still takes taps', (tester) async {
    var pressed = 0;
    final context = await pumpPage(tester, onControlPressed: () => pressed++);
    await show(tester, context);
    expect(_toast, findsOneWidget);
    await tester.tap(_bottomControl);
    expect(pressed, 1);
    expect(find.byTooltip('Close').hitTestable(), findsOneWidget);
    await dismiss(tester);
  });

  testWidgets('a control mid-way through an entrance scale is avoided where '
      'it comes to rest', (tester) async {
    tester.view.physicalSize = _screen;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late BuildContext context;
    await tester.pumpWidget(
      ToastWrapper(
        child: MaterialApp(
          home: Builder(
            builder: (value) {
              context = value;
              return Scaffold(
                body: Stack(
                  children: [
                    Positioned(
                      left: AppSpacing.lg,
                      bottom: AppSpacing.lg,
                      child: Transform.scale(
                        scale: .3,
                        child: const ToastAvoidArea(
                          child: SizedBox(
                            key: ValueKey('bottomControl'),
                            width: 240,
                            height: 80,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await show(tester, context);
    // The full-size control's top, not the scaled-down one's.
    expect(
      tester.getRect(_toast).bottom,
      closeTo(_screen.height - AppSpacing.lg - 80 - AppSpacing.sm, .01),
    );
    await dismiss(tester);
  });

  testWidgets('a hidden control is not avoided', (tester) async {
    final context = await pumpPage(tester, enabled: false);
    await show(tester, context);
    expect(tester.getRect(_toast).bottom, _screen.height - AppSpacing.lg);
    await dismiss(tester);
  });

  testWidgets('a marked area in the upper half is not a bottom control', (
    tester,
  ) async {
    final context = await pumpPage(tester, controlBottom: 600);
    await show(tester, context);
    expect(tester.getRect(_toast).bottom, _screen.height - AppSpacing.lg);
    await dismiss(tester);
  });

  testWidgets('a control on a route covered by an opaque route is not '
      'avoided, and the lift follows each new toast', (tester) async {
    final context = await pumpPage(tester);
    await show(tester, context);
    final lifted = tester.getRect(_toast).bottom;
    expect(lifted, lessThan(_screen.height - AppSpacing.lg));
    await dismiss(tester);

    late BuildContext covering;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (value) {
          covering = value;
          return const Scaffold(body: SizedBox.expand());
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(_bottomControl, findsNothing);
    await show(tester, covering);
    expect(tester.getRect(_toast).bottom, _screen.height - AppSpacing.lg);
    await dismiss(tester);
  });

  group('ToastNavigatorObserver', () {
    Future<NavigatorState> pumpObserved(WidgetTester tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        ToastWrapper(
          child: MaterialApp(
            navigatorKey: navigatorKey,
            navigatorObservers: [ToastNavigatorObserver()],
            home: const Scaffold(body: SizedBox.expand()),
          ),
        ),
      );
      return navigatorKey.currentState!;
    }

    testWidgets('a sheet opening dismisses a lingering error so it cannot '
        'cover the sheet commands', (tester) async {
      final navigator = await pumpObserved(tester);
      await show(tester, navigator.context);
      expect(find.text('Not saved'), findsOneWidget);
      showModalBottomSheet<void>(
        context: navigator.context,
        builder: (_) => const SizedBox(height: 200),
      );
      await tester.pumpAndSettle();
      expect(find.text('Not saved'), findsNothing);
    });

    testWidgets('a page route keeps the toast', (tester) async {
      final navigator = await pumpObserved(tester);
      await show(tester, navigator.context);
      navigator.push(
        MaterialPageRoute<void>(builder: (_) => const Scaffold()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Not saved'), findsOneWidget);
      await dismiss(tester);
    });
  });

  for (final theme in [AppTheme.light(), AppTheme.dark()]) {
    for (final type in NotificationType.values) {
      testWidgets('a ${type.name} toast is a neutral plate with a colored '
          'glyph: ${theme.brightness}', (tester) async {
        final context = await pumpPage(tester, avoid: false, theme: theme);
        showToast(context, type: type, message: 'Saved');
        await tester.pump();
        await tester.pumpAndSettle();
        final colors = theme.colorScheme;
        final plate = tester
            .widget<Material>(
              find
                  .descendant(of: _toast, matching: find.byType(Material))
                  .first,
            )
            .color!;
        expect(plate, colors.inverseSurface);
        final text = DefaultTextStyle.of(tester.element(find.text('Saved')));
        expect(text.style.color, colors.onInverseSurface);
        expect(
          _contrast(colors.onInverseSurface, plate),
          greaterThanOrEqualTo(4.5),
        );
        final glyph = tester.widget<Icon>(
          find.byIcon(switch (type) {
            NotificationType.success => AppIcons.check,
            NotificationType.error => AppIcons.error,
          }),
        );
        expect(
          glyph.color,
          switch (type) {
            NotificationType.success => theme.ext.successOnInverse,
            NotificationType.error => theme.ext.errorOnInverse,
          },
        );
        expect(_contrast(glyph.color!, plate), greaterThanOrEqualTo(3));
        // The plate stands apart from the page in both themes.
        expect(
          _contrast(plate, theme.scaffoldBackgroundColor),
          greaterThanOrEqualTo(3),
        );
        await dismiss(tester);
      });
    }
  }
}
