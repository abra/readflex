import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester, {required bool busy}) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: busy ? null : () {},
              child: AppBusyButtonLabel('Save', busy: busy),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('busy keeps the button size and announces the label', (
    tester,
  ) async {
    await pump(tester, busy: false);
    final idle = tester.getSize(find.byType(FilledButton));
    expect(find.text('Save'), findsOneWidget);
    expect(find.byType(ButtonLoadingIndicator), findsNothing);

    await pump(tester, busy: true);
    expect(tester.getSize(find.byType(FilledButton)), idle);
    expect(find.byType(ButtonLoadingIndicator), findsOneWidget);
    final hidden = tester.widget<Visibility>(find.byType(Visibility));
    expect(hidden.visible, isFalse);
    expect(hidden.maintainSize, isTrue);
    final live = tester.getSemantics(find.byType(ButtonLoadingIndicator));
    expect(live.label, 'Save');
    expect(live.flagsCollection.isLiveRegion, isTrue);
  });

  testWidgets('shared by AppSheetActions and ErrorState', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Column(
            children: [
              AppSheetActions(
                primaryLabel: 'Save',
                onPrimary: () {},
                secondaryLabel: 'Cancel',
                onSecondary: () {},
                busy: true,
              ),
              ErrorState(
                message: 'Failed',
                retryLabel: 'Retry',
                onRetry: () {},
                busy: true,
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.byType(AppBusyButtonLabel), findsNWidgets(2));
    expect(find.byType(ButtonLoadingIndicator), findsNWidgets(2));
  });
}
