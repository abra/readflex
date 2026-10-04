import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toast_service/toast_service.dart';
import 'package:toastification/toastification.dart';

void main() {
  setUp(() => toastification.managers.clear());

  for (final direction in TextDirection.values) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'toast close target is accessible in $direction/$brightness',
        (
          tester,
        ) async {
          final semantics = tester.ensureSemantics();
          try {
            final context = await _mount(tester, direction, brightness);
            showToast(
              context,
              type: NotificationType.error,
              message: 'Try again',
            );
            await tester.pump();
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 650));

            final close = find.byTooltip('Close');
            expect(close, findsOneWidget);
            expect(tester.getSize(close), const Size.square(48));
            await expectLater(
              tester,
              meetsGuideline(androidTapTargetGuideline),
            );
            await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
            await expectLater(
              tester,
              meetsGuideline(labeledTapTargetGuideline),
            );
            final button = tester.widget<IconButton>(
              find.byType(IconButton),
            );
            expect(button.style!.shape!.resolve({}), isA<CircleBorder>());
            await tester.tapAt(tester.getTopLeft(close) + const Offset(2, 2));
            await tester.pumpAndSettle();
            expect(find.text('Try again'), findsNothing);
          } finally {
            semantics.dispose();
          }
        },
      );
    }

    testWidgets('large text preserves a long suffix in $direction', (
      tester,
    ) async {
      final context = await _mount(
        tester,
        direction,
        Brightness.light,
        size: const Size(280, 568),
        scale: 2,
      );
      const title = 'A long book title containing several words';
      const suffix = ' has been removed from the library';
      showToast(
        context,
        type: NotificationType.success,
        message: title,
        messageSuffix: suffix,
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 650));
      expect(tester.takeException(), isNull);
      expect(find.text(suffix.trimLeft()), findsOneWidget);
      final toast = tester.getRect(find.byType(BuiltInContainer));
      expect(toast.left, greaterThanOrEqualTo(AppSpacing.lg));
      expect(280 - toast.right, greaterThanOrEqualTo(AppSpacing.lg));
      await _dismiss(tester);
    });
  }

  testWidgets('swiping dismisses only the selected notification', (
    tester,
  ) async {
    final context = await _mount(tester, TextDirection.ltr, Brightness.light);
    showToast(context, type: NotificationType.error, message: 'First error');
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 650));
    showToast(context, type: NotificationType.error, message: 'Second error');
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 650));
    expect(
      toastification.managers[Alignment.topCenter]!.notifications,
      hasLength(2),
      reason:
          'an idle overlay must schedule the second toast without user input',
    );
    await tester.drag(find.text('Second error'), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(find.text('Second error'), findsNothing);
    expect(find.text('First error'), findsOneWidget);
    await _dismiss(tester);
  });

  testWidgets('all four corners of the Close target dismiss the toast', (
    tester,
  ) async {
    final context = await _mount(tester, TextDirection.ltr, Brightness.light);
    for (final corner in [
      Alignment.topLeft,
      Alignment.topRight,
      Alignment.bottomLeft,
      Alignment.bottomRight,
    ]) {
      showToast(context, type: NotificationType.error, message: 'Try again');
      await tester.pump();
      await tester.pumpAndSettle();
      final rect = tester.getRect(find.byTooltip('Close')).deflate(2);
      await tester.tapAt(corner.withinRect(rect));
      await tester.pumpAndSettle();
      expect(find.text('Try again'), findsNothing);
    }
  });

  testWidgets('visible toast adapts to rotation and safe-area insets', (
    tester,
  ) async {
    final context = await _mount(tester, TextDirection.ltr, Brightness.light);
    showToast(context, type: NotificationType.error, message: 'Try again');
    addTearDown(tester.view.resetViewPadding);
    await tester.pump();
    await tester.pumpAndSettle();
    for (final size in [
      const Size(390, 844),
      const Size(844, 390),
      const Size(280, 568),
      const Size(390, 844),
    ]) {
      tester.view.physicalSize = size;
      tester.view.viewPadding = const FakeViewPadding(
        left: 20,
        right: 12,
        top: 44,
      );
      await tester.pumpAndSettle();
      final rect = tester.getRect(find.byType(BuiltInContainer));
      expect(rect.left, greaterThanOrEqualTo(20 + AppSpacing.lg));
      expect(size.width - rect.right, greaterThanOrEqualTo(12 + AppSpacing.lg));
      expect(rect.top, 44 + AppSpacing.md);
      expect(rect.width, lessThanOrEqualTo(520));
      expect(find.byTooltip('Close').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('toast announces full text independently of its Close action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final context = await _mount(tester, TextDirection.ltr, Brightness.light);
      const message = 'A long title with a complete message for screen readers';
      showToast(
        context,
        type: NotificationType.error,
        message: message,
        messageSuffix: ' removed',
      );
      await tester.pump();
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.bySemanticsLabel('$message removed')),
        matchesSemantics(label: '$message removed', isLiveRegion: true),
      );
      expect(find.byTooltip('Close').hitTestable(), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });
}

Future<BuildContext> _mount(
  WidgetTester tester,
  TextDirection direction,
  Brightness brightness, {
  Size size = const Size(390, 844),
  double scale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  late BuildContext context;
  await tester.pumpWidget(
    ToastWrapper(
      child: MaterialApp(
        theme: brightness == Brightness.light
            ? AppTheme.light()
            : AppTheme.dark(),
        builder: (context, child) => Directionality(
          textDirection: direction,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              accessibleNavigation: true,
              disableAnimations: true,
            ),
            child: child!,
          ),
        ),
        home: Builder(
          builder: (value) {
            context = value;
            return const Scaffold(body: SizedBox.shrink());
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  addTearDown(() => _dismiss(tester));
  return context;
}

Future<void> _dismiss(WidgetTester tester) async {
  toastification.dismissAll(delayForAnimation: false);
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}
