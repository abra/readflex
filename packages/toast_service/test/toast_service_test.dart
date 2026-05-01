import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toast_service/toast_service.dart';

void main() {
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
}
