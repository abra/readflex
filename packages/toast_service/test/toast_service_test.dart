import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toast_service/toast_service.dart';
import 'package:toastification/toastification.dart';

void main() {
  setUp(() => toastification.managers.clear());

  testWidgets('accessible error remains until explicitly dismissed', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            accessibleNavigation: true,
            disableAnimations: true,
          ),
          child: ToastWrapper(
            child: Builder(
              builder: (value) {
                context = value;
                return const Scaffold(body: SizedBox.shrink());
              },
            ),
          ),
        ),
      ),
    );
    showToast(context, type: NotificationType.error, message: 'Could not save');
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));
    expect(
      toastification.managers[Alignment.bottomCenter]!.notifications,
      hasLength(1),
    );
    expect(find.text('Could not save'), findsOneWidget);
    final close = find.byTooltip('Close');
    expect(close.hitTestable(), findsOneWidget);
    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(find.text('Could not save'), findsNothing);
  });

  testWidgets('ToastWrapper renders its child', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ToastWrapper(child: Text('hello')),
      ),
    );
    expect(find.text('hello'), findsOneWidget);
  });

  testWidgets('showToast does not throw inside a ToastWrapper', (tester) async {
    late BuildContext capturedContext;
    await tester.pumpWidget(
      MaterialApp(
        home: ToastWrapper(
          child: Builder(
            builder: (context) {
              capturedContext = context;
              return const Scaffold(body: SizedBox.shrink());
            },
          ),
        ),
      ),
    );

    expect(
      () => showToast(
        capturedContext,
        type: NotificationType.success,
        message: 'Book deleted',
      ),
      returnsNormally,
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(toastSuccessDuration);
    // Allow the exit animation and overlay cleanup to finish.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  });

  test('success stays long enough to read a title; errors stay longer', () {
    expect(toastSuccessDuration, const Duration(seconds: 4));
    expect(toastErrorDuration, greaterThan(toastSuccessDuration));
  });

  for (final type in NotificationType.values) {
    testWidgets('${type.name} toast uses the notification reading time', (
      tester,
    ) async {
      late BuildContext capturedContext;
      await tester.pumpWidget(
        MaterialApp(
          home: ToastWrapper(
            child: Builder(
              builder: (context) {
                capturedContext = context;
                return const Scaffold(body: SizedBox.shrink());
              },
            ),
          ),
        ),
      );

      showToast(capturedContext, type: type, message: 'Toast message');
      await tester.pump();
      await tester.pump();
      final milliseconds = switch (type) {
        NotificationType.error => toastErrorDuration.inMilliseconds,
        NotificationType.success => toastSuccessDuration.inMilliseconds,
      };
      await tester.pump(Duration(milliseconds: milliseconds - 1));
      expect(find.text('Toast message'), findsOneWidget);
      final manager = toastification.managers[Alignment.bottomCenter]!;
      expect(manager.notifications, hasLength(1));

      await tester.pump(const Duration(milliseconds: 1));
      expect(manager.notifications, isEmpty);
      // Allow the existing exit animation and overlay cleanup to finish.
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Toast message'), findsNothing);
      await tester.pumpAndSettle();
    });
  }
}
