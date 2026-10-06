import 'dart:async';

import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readflex/app/screens/initialization_failed_screen.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

void main() {
  testWidgets('recovery keeps app theme and hides diagnostics initially', (
    tester,
  ) async {
    await tester.pumpWidget(
      InitializationFailedScreen(
        error: StateError('private debug detail'),
        stackTrace: StackTrace.fromString('stack detail'),
        onRetryInitialization: () async {},
      ),
    );
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme, AppTheme.light());
    expect(app.darkTheme, AppTheme.dark());
    expect(
      find.textContaining('private debug detail').hitTestable(),
      findsNothing,
    );
    expect(find.textContaining('stack detail').hitTestable(), findsNothing);
    await tester.tap(find.text('Technical details'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('private debug detail').hitTestable(),
      findsOneWidget,
    );
  });
  Widget screen(Future<void> Function() retry) => InitializationFailedScreen(
    error: StateError('Initialization failed'),
    stackTrace: StackTrace.empty,
    onRetryInitialization: retry,
  );

  testWidgets('retry stays disabled until the attempt completes', (
    tester,
  ) async {
    final completion = Completer<void>();
    var attempts = 0;
    await tester.pumpWidget(
      screen(() {
        attempts++;
        return completion.future;
      }),
    );

    await tester.tap(find.byType(FilledButton));
    // A second tap can arrive before the disabled button has been rebuilt.
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(attempts, 1);
    completion.complete();
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('retry may complete after the recovery screen is removed', (
    tester,
  ) async {
    final completion = Completer<void>();
    await tester.pumpWidget(screen(() => completion.future));
    await tester.tap(find.byType(FilledButton));
    await tester.pumpWidget(const SizedBox.shrink());

    completion.complete();
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('a throwing retry reports its error and re-enables the button', (
    tester,
  ) async {
    final completion = Completer<void>();
    final error = StateError('Retry failed');
    await tester.pumpWidget(screen(() => completion.future));
    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    completion.completeError(error);
    await tester.pump();

    expect(tester.takeException(), same(error));
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('centres the shared error state at the 16dp gutter with the '
      'diagnostics below', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    // Large text makes the body wrap so its edges show the gutter.
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(screen(() async {}));
    final state = find.byType(ErrorState);
    expect(state, findsOneWidget);
    final context = tester.element(state);
    final l10n = ReadflexLocalizations.of(context)!;
    expect(find.byIcon(AppIcons.error), findsOneWidget);
    expect(find.byIcon(AppIcons.refresh), findsNothing);
    expect(find.widgetWithText(FilledButton, l10n.appRetry), findsOneWidget);
    final title = tester.widget<Text>(find.text(l10n.appInitializationFailed));
    expect(title.style!.fontSize, context.text.titleMedium.fontSize);
    expect(title.textAlign, TextAlign.center);

    // The state applies the gutter once: text wraps at 16, not 32.
    final body = tester.getRect(find.text(l10n.appInitializationFailedBody));
    expect(body.left, AppSpacing.lg);
    expect(body.right, 390 - AppSpacing.lg);
    final tile = tester.getRect(find.byType(ExpansionTile));
    expect(tile.left, AppSpacing.lg);
    expect(tile.right, 390 - AppSpacing.lg);
    // Centred in the space above the diagnostics tile.
    final column = tester.getRect(
      find.descendant(of: state, matching: find.byType(Column)).first,
    );
    final above = column.top;
    final below = tile.top - AppSpacing.lg - column.bottom;
    expect(above, greaterThan(0));
    expect(above, closeTo(below, 1));
    expect(find.byType(SingleChildScrollView), findsNothing);
  });

  testWidgets('expanded diagnostics scroll the page instead of clipping', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      InitializationFailedScreen(
        error: StateError('boom'),
        stackTrace: StackTrace.fromString(
          List.filled(
            80,
            '#0 frame (package:readflex/app.dart:1:1)',
          ).join('\n'),
        ),
        onRetryInitialization: () async {},
      ),
    );
    final scrollable = find.byType(Scrollable).first;
    expect(
      tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
      0,
    );
    await tester.tap(find.text('Technical details'));
    await tester.pumpAndSettle();
    expect(
      tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
      greaterThan(0),
    );
    final position = tester.state<ScrollableState>(scrollable).position;
    position.jumpTo(position.maxScrollExtent);
    await tester.pump();
    // The end of the trace is reachable inside the viewport.
    expect(
      tester.getRect(find.textContaining('boom')).bottom,
      lessThanOrEqualTo(844),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('busy retry keeps its geometry and shows progress', (
    tester,
  ) async {
    final completion = Completer<void>();
    await tester.pumpWidget(screen(() => completion.future));
    final idle = tester.getSize(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(find.byType(ButtonLoadingIndicator), findsOneWidget);
    expect(tester.getSize(find.byType(FilledButton)), idle);
    completion.complete();
    await tester.pumpAndSettle();
    expect(find.byType(ButtonLoadingIndicator), findsNothing);
  });

  testWidgets('without a retry callback the message keeps the frame', (
    tester,
  ) async {
    await tester.pumpWidget(
      InitializationFailedScreen(
        error: StateError('x'),
        stackTrace: StackTrace.empty,
      ),
    );
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.byIcon(AppIcons.error), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    final column = tester.getRect(
      find
          .descendant(
            of: find.byType(EmptyState),
            matching: find.byType(Column),
          )
          .first,
    );
    final tile = tester.getRect(find.byType(ExpansionTile));
    expect(tile.left, AppSpacing.lg);
    expect(column.top, closeTo(tile.top - AppSpacing.lg - column.bottom, 1));
  });
}
