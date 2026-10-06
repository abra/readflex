import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child, {ThemeData? theme}) => MaterialApp(
    theme: theme ?? AppTheme.light(),
    home: Scaffold(body: child),
  );

  group('ErrorState', () {
    testWidgets('renders title, icon, message and a filled retry', (
      tester,
    ) async {
      var retried = 0;
      await tester.pumpWidget(
        host(
          ErrorState(
            title: 'Could not open',
            message: 'The file is damaged',
            icon: AppIcons.error,
            retryLabel: 'Retry',
            onRetry: () => retried++,
          ),
        ),
      );
      expect(find.text('Could not open'), findsOneWidget);
      expect(find.text('The file is damaged'), findsOneWidget);
      expect(find.byIcon(AppIcons.error), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.byType(OutlinedButton), findsNothing);
      await tester.tap(find.text('Retry'));
      expect(retried, 1);
      expect(tester, meetsGuideline(androidTapTargetGuideline));
    });

    testWidgets('secondary command is outlined and sits beside retry', (
      tester,
    ) async {
      var back = 0;
      await tester.pumpWidget(
        host(
          ErrorState(
            message: 'Failed',
            retryLabel: 'Retry',
            onRetry: () {},
            secondaryLabel: 'Go back',
            onSecondary: () => back++,
          ),
        ),
      );
      final retry = tester.getRect(find.byType(FilledButton));
      final secondary = tester.getRect(find.byType(OutlinedButton));
      expect(secondary.right, lessThanOrEqualTo(retry.left));
      await tester.tap(find.text('Go back'));
      expect(back, 1);
    });

    testWidgets('busy keeps geometry and blocks both commands', (
      tester,
    ) async {
      var busy = false;
      late StateSetter update;
      await tester.pumpWidget(
        host(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return ErrorState(
                message: 'Failed',
                retryLabel: 'Retry',
                onRetry: () {},
                secondaryLabel: 'Go back',
                onSecondary: () {},
                busy: busy,
              );
            },
          ),
        ),
      );
      final before = tester.getRect(find.byType(FilledButton));
      update(() => busy = true);
      await tester.pump();
      expect(tester.getRect(find.byType(FilledButton)), before);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
      expect(find.byType(ButtonLoadingIndicator), findsOneWidget);
    });

    testWidgets('secondary label and callback must come together', (
      tester,
    ) async {
      expect(
        () => ErrorState(
          message: 'Failed',
          retryLabel: 'Retry',
          onRetry: () {},
          secondaryLabel: 'Go back',
        ),
        throwsAssertionError,
      );
    });
  });

  group('EmptyState', () {
    testWidgets('default uses titleMedium, compact uses muted bodyMedium', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const Column(
            children: [
              Expanded(child: EmptyState(message: 'Nothing here')),
              Expanded(child: EmptyState(message: 'No matches', compact: true)),
            ],
          ),
        ),
      );
      final context = tester.element(find.byType(EmptyState).first);
      final heading = tester.widget<Text>(find.text('Nothing here'));
      final compact = tester.widget<Text>(find.text('No matches'));
      expect(heading.style?.fontSize, context.text.titleMedium.fontSize);
      expect(compact.style?.fontSize, context.text.bodyMedium.fontSize);
      expect(compact.style?.color, context.colors.onSurfaceVariant);
    });

    testWidgets('icon sits in the shared state frame', (tester) async {
      await tester.pumpWidget(
        host(const EmptyState(message: 'Empty', icon: AppIcons.search)),
      );
      final frame = find.ancestor(
        of: find.byIcon(AppIcons.search),
        matching: find.byType(Container),
      );
      expect(tester.getSize(frame.first), const Size(56, 56));
      expect(
        tester.widget<Icon>(find.byIcon(AppIcons.search)).size,
        AppIconSize.md,
      );
    });
  });

  group('AppStatusMessage', () {
    testWidgets('renders title, body and an optional filled action', (
      tester,
    ) async {
      var pressed = 0;
      await tester.pumpWidget(
        host(
          AppStatusMessage(
            title: 'No definition',
            body: 'Try another word',
            actionLabel: 'Retry',
            onAction: () => pressed++,
          ),
        ),
      );
      expect(find.text('No definition'), findsOneWidget);
      expect(find.text('Try another word'), findsOneWidget);
      await tester.tap(find.byType(FilledButton));
      expect(pressed, 1);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('busy shows progress and disables the action', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          AppStatusMessage(
            title: 'Downloading',
            body: 'Language models',
            actionLabel: 'Download',
            onAction: () {},
            busy: true,
          ),
        ),
      );
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
    });

    testWidgets('without an action label renders no button', (tester) async {
      await tester.pumpWidget(
        host(const AppStatusMessage(title: 'Offline', body: 'Reconnect')),
      );
      expect(find.byType(FilledButton), findsNothing);
    });
  });

  group('AppSourceQuote', () {
    testWidgets('rule and inset follow the quote direction, not the app', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: SizedBox(
                width: 200,
                child: AppSourceQuote(
                  textDirection: TextDirection.rtl,
                  child: Text('مرحبا'),
                ),
              ),
            ),
          ),
        ),
      );
      final quote = tester.getRect(find.byType(AppSourceQuote));
      final textRect = tester.getRect(find.text('مرحبا'));
      // RTL quote: inset and rule on the right, text ends at the right inset.
      expect(quote.right - textRect.right, closeTo(AppSpacing.md + 2, 0.5));
      expect(
        tester
            .widget<Directionality>(
              find
                  .descendant(
                    of: find.byType(AppSourceQuote),
                    matching: find.byType(Directionality),
                  )
                  .first,
            )
            .textDirection,
        TextDirection.rtl,
      );
    });
  });

  group('SelectionPreviewCard', () {
    testWidgets('applies the content direction to the preview text', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const SelectionPreviewCard(
            text: 'مرحبا',
            textDirection: TextDirection.rtl,
          ),
        ),
      );
      expect(
        tester.widget<Text>(find.text('مرحبا')).textDirection,
        TextDirection.rtl,
      );
    });
  });

  group('AppSheetActions', () {
    testWidgets('destructive secondary is outlined in the error color while '
        'the primary stays the filled safe default', (tester) async {
      await tester.pumpWidget(
        host(
          AppSheetActions(
            primaryLabel: 'Cancel',
            onPrimary: () {},
            secondaryLabel: 'Delete',
            onSecondary: () {},
            destructiveSecondary: true,
          ),
        ),
      );
      final context = tester.element(find.byType(AppSheetActions));
      final outlined = tester.widget<OutlinedButton>(
        find.byType(OutlinedButton),
      );
      expect(
        outlined.style?.foregroundColor?.resolve({}),
        context.colors.error,
      );
      expect(outlined.style?.side?.resolve({})?.color, context.colors.error);
      expect(find.widgetWithText(FilledButton, 'Cancel'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Delete'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).style,
        isNull,
      );
    });
  });

  group('AppPlainIconButton', () {
    testWidgets('accepts a custom icon widget and keeps the 48dp circle', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        host(
          Center(
            child: AppPlainIconButton(
              iconWidget: const SizedBox(
                key: Key('glyph'),
                width: 24,
                height: 24,
              ),
              tooltip: 'Bookmark',
              onPressed: () => taps++,
            ),
          ),
        ),
      );
      expect(find.byKey(const Key('glyph')), findsOneWidget);
      final button = find.byType(IconButton);
      expect(tester.getSize(button), const Size(48, 48));
      expect(
        tester.widget<IconButton>(button).style!.shape!.resolve({}),
        isA<CircleBorder>(),
      );
      await tester.tap(button);
      expect(taps, 1);
    });

    testWidgets('disabled state dims the given color instead of swapping it', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const Center(
            child: AppPlainIconButton(
              icon: AppIcons.close,
              tooltip: 'Close',
              onPressed: null,
              color: Colors.red,
            ),
          ),
        ),
      );
      final style = tester.widget<IconButton>(find.byType(IconButton)).style!;
      final disabled = style.foregroundColor!.resolve({WidgetState.disabled});
      expect(disabled, Colors.red.withValues(alpha: 0.38));
    });

    testWidgets('requires exactly one of icon or iconWidget', (tester) async {
      expect(
        () => AppPlainIconButton(tooltip: 'x', onPressed: () {}),
        throwsAssertionError,
      );
      expect(
        () => AppPlainIconButton(
          tooltip: 'x',
          onPressed: () {},
          icon: AppIcons.close,
          iconWidget: const SizedBox(),
        ),
        throwsAssertionError,
      );
    });
  });

  group('AppColorsExt swatch inks', () {
    test('both themes expose a dark ink for light swatches and a light ink '
        'for dark swatches', () {
      for (final theme in [AppTheme.light(), AppTheme.dark()]) {
        final ext = theme.ext;
        expect(ext.onLightSwatch.computeLuminance(), lessThan(0.2));
        expect(ext.onDarkSwatch.computeLuminance(), greaterThan(0.8));
      }
    });
  });
}
