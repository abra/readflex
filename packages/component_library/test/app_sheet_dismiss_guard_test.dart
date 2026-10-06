import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Opens a sheet whose body toggles its guard from a button, returning
  /// counters for dismiss attempts and route completion.
  Future<({int Function() attempts, int Function() closed})> openGuardedSheet(
    WidgetTester tester, {
    required bool initiallyGuarded,
    bool scrimClosesFlow = false,
  }) async {
    var attempts = 0;
    var closed = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showAppBottomSheet<void>(
                context,
                scrimClosesFlow: scrimClosesFlow,
                builder: (_) => _GuardedBody(
                  initiallyGuarded: initiallyGuarded,
                  onDismissAttempt: () => attempts++,
                ),
              ).whenComplete(() => closed++),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    return (attempts: () => attempts, closed: () => closed);
  }

  Finder dragHandle() => find.byWidgetPredicate(
    (w) => w is Container && w.constraints?.maxWidth == 32,
  );

  testWidgets('a guarded step routes scrim taps to the guard and stays open', (
    tester,
  ) async {
    final sheet = await openGuardedSheet(tester, initiallyGuarded: true);
    await tester.tapAt(const Offset(10, 20));
    await tester.pumpAndSettle();
    expect(sheet.attempts(), 1);
    expect(sheet.closed(), 0);
    expect(find.byType(BottomSheet), findsOneWidget);
  });

  testWidgets('a guarded step hides the drag handle and swallows drag-down', (
    tester,
  ) async {
    final sheet = await openGuardedSheet(tester, initiallyGuarded: true);
    expect(dragHandle(), findsNothing);
    final before = tester.getTopLeft(find.byType(BottomSheet));
    await tester.drag(find.text('Body'), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(tester.getTopLeft(find.byType(BottomSheet)), before);
    expect(sheet.closed(), 0);
  });

  testWidgets('an unguarded step keeps normal scrim and drag dismissal', (
    tester,
  ) async {
    final sheet = await openGuardedSheet(
      tester,
      initiallyGuarded: false,
      scrimClosesFlow: true,
    );
    expect(dragHandle(), findsOneWidget);
    await tester.drag(find.text('Body'), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(sheet.attempts(), 0);
    expect(sheet.closed(), 1);
  });

  testWidgets('scrim without scrimClosesFlow still pops an unguarded step', (
    tester,
  ) async {
    final sheet = await openGuardedSheet(tester, initiallyGuarded: false);
    await tester.tapAt(const Offset(10, 20));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(sheet.closed(), 1);
  });

  testWidgets('toggling the guard off restores the handle and dismissal', (
    tester,
  ) async {
    final sheet = await openGuardedSheet(tester, initiallyGuarded: true);
    await tester.tap(find.text('Toggle'));
    // Guard changes publish after the frame, then the route rebuilds.
    await tester.pump();
    await tester.pump();
    expect(dragHandle(), findsOneWidget);
    await tester.tapAt(const Offset(10, 20));
    await tester.pumpAndSettle();
    expect(sheet.attempts(), 0);
    expect(sheet.closed(), 1);
  });

  testWidgets('toggling the guard on after opening blocks the scrim', (
    tester,
  ) async {
    final sheet = await openGuardedSheet(tester, initiallyGuarded: false);
    await tester.tap(find.text('Toggle'));
    await tester.pump();
    await tester.pump();
    expect(dragHandle(), findsNothing);
    await tester.tapAt(const Offset(10, 20));
    await tester.pumpAndSettle();
    expect(sheet.attempts(), 1);
    expect(find.byType(BottomSheet), findsOneWidget);
  });

  testWidgets('popping a guarded sheet programmatically does not throw', (
    tester,
  ) async {
    await openGuardedSheet(tester, initiallyGuarded: true);
    await tester.tap(find.text('Pop'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a guard outside any app sheet is inert', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: AppSheetDismissGuard(
          enabled: true,
          onDismissAttempt: () {},
          child: const Text('Plain'),
        ),
      ),
    );
    expect(find.text('Plain'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _GuardedBody extends StatefulWidget {
  const _GuardedBody({
    required this.initiallyGuarded,
    required this.onDismissAttempt,
  });

  final bool initiallyGuarded;
  final VoidCallback onDismissAttempt;

  @override
  State<_GuardedBody> createState() => _GuardedBodyState();
}

class _GuardedBodyState extends State<_GuardedBody> {
  late bool _guarded = widget.initiallyGuarded;

  @override
  Widget build(BuildContext context) {
    return AppSheetDismissGuard(
      enabled: _guarded,
      onDismissAttempt: widget.onDismissAttempt,
      child: SizedBox(
        height: 200,
        child: Column(
          children: [
            const Text('Body'),
            TextButton(
              onPressed: () => setState(() => _guarded = !_guarded),
              child: const Text('Toggle'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Pop'),
            ),
          ],
        ),
      ),
    );
  }
}
