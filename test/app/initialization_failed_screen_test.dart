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

  testWidgets('uses the shared error state inside a 16dp gutter', (
    tester,
  ) async {
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
    final scroll = tester.widget<SingleChildScrollView>(
      find.byType(SingleChildScrollView),
    );
    expect(scroll.padding, const EdgeInsets.all(AppSpacing.lg));
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
  });
}
