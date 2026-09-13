import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toast_service/toast_service.dart';
import 'package:toastification/toastification.dart';

void main() {
  setUp(() => toastification.managers.clear());

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
    await tester.pumpAndSettle(const Duration(seconds: 4));
  });

  for (final type in NotificationType.values) {
    testWidgets('${type.name} toast auto-closes after one second', (
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
      await tester.pump(const Duration(milliseconds: 999));
      expect(find.text('Toast message'), findsOneWidget);
      final manager = toastification.managers[Alignment.topCenter]!;
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
