import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('compact body inset preserves the shared header and gutters', (
    tester,
  ) async {
    const bodyKey = ValueKey('body');
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 320,
              child: ActionBottomSheetLayout.scrollable(
                title: 'Language',
                onClose: () {},
                closeLabel: 'Close',
                bodyPadding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: const SizedBox(key: bodyKey, height: 96),
              ),
            ),
          ),
        ),
      ),
    );
    final sheet = tester.getRect(find.byType(ActionBottomSheetLayout));
    final body = tester.getRect(find.byKey(bodyKey));
    final header = tester.getRect(find.byType(BottomSheetHeader));
    expect(sheet.bottom - body.bottom, 8);
    expect(body.left - sheet.left, 24);
    expect(sheet.right - body.right, 24);
    expect(body.top - header.bottom, 8);
    expect(tester.getRect(find.byIcon(AppIcons.close)).right, body.right);
    expect(tester.getSize(find.byType(AppPlainIconButton)), const Size(48, 48));
    expect(
      tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position
          .maxScrollExtent,
      0,
    );
    expect(tester.takeException(), isNull);
  });

  for (final direction in TextDirection.values) {
    testWidgets(
      'large sheet title gets full width below navigation $direction',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: Directionality(
                textDirection: direction,
                child: MediaQuery(
                  data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                  child: SizedBox(
                    width: 280,
                    child: BottomSheetHeader(
                      title: 'Title words',
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      onBack: () {},
                      backLabel: 'Back',
                      onClose: () {},
                      closeLabel: 'Close',
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final title = tester.getRect(find.text('Title words'));
        final header = tester.getRect(find.byType(BottomSheetHeader));
        final back = tester.getRect(find.byTooltip('Back'));
        final close = tester.getRect(find.byTooltip('Close'));
        expect(title.left - header.left, 24);
        expect(header.right - title.right, 24);
        expect(title.top, greaterThan(back.bottom));
        expect(back.top, close.top);
        expect(back.size, const Size(48, 48));
        expect(close.size, back.size);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final direction in TextDirection.values) {
    testWidgets('sheet back and close share aligned 48dp targets $direction', (
      tester,
    ) async {
      var backs = 0;
      var closes = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Directionality(
              textDirection: direction,
              child: SizedBox(
                width: 320,
                child: ActionBottomSheetLayout.scrollable(
                  title: 'Language',
                  onBack: () => backs++,
                  backLabel: 'Back',
                  onClose: () => closes++,
                  closeLabel: 'Close',
                  child: const SizedBox(height: 100),
                ),
              ),
            ),
          ),
        ),
      );
      final ltr = direction == TextDirection.ltr;
      final sheet = tester.getRect(find.byType(ActionBottomSheetLayout));
      final back = tester.getRect(find.byTooltip('Back'));
      final close = tester.getRect(find.byTooltip('Close'));
      final backIcon = tester.getRect(
        find.byIcon(ltr ? AppIcons.chevronLeft : AppIcons.chevronRight),
      );
      final closeIcon = tester.getRect(find.byIcon(AppIcons.close));
      expect(back.size, const Size(48, 48));
      expect(close.size, back.size);
      expect(back.center.dy, close.center.dy);
      expect(
        ltr ? backIcon.left - sheet.left : sheet.right - backIcon.right,
        24,
      );
      expect(
        ltr ? sheet.right - closeIcon.right : closeIcon.left - sheet.left,
        24,
      );
      await tester.tapAt(back.topLeft + const Offset(2, 2));
      expect(backs, 1);
      expect(closes, 0);
      await tester.tapAt(close.topLeft + const Offset(2, 2));
      expect(closes, 1);
      expect(tester.takeException(), isNull);
    });
  }

  for (final direction in TextDirection.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('close icon aligns with content in $direction at $scale', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        try {
          var closes = 0;
          var resets = 0;
          const bodyKey = ValueKey('body');
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light(),
              home: Scaffold(
                body: Directionality(
                  textDirection: direction,
                  child: MediaQuery(
                    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: 320,
                        child: ActionBottomSheetLayout(
                          title: 'A long localized sheet title',
                          closeLabel: 'Close',
                          onClose: () => closes++,
                          headerTrailing: TextButton(
                            onPressed: () => resets++,
                            child: const Text('Reset'),
                          ),
                          child: const SizedBox(key: bodyKey, height: 80),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          final ltr = direction == TextDirection.ltr;
          final body = tester.getRect(find.byKey(bodyKey));
          final title = tester.getRect(
            find.text('A long localized sheet title'),
          );
          final icon = tester.getRect(find.byIcon(AppIcons.close));
          final button = tester.getRect(find.byType(AppPlainIconButton));
          final sheet = tester.getRect(find.byType(ActionBottomSheetLayout));
          expect(ltr ? title.left : title.right, ltr ? body.left : body.right);
          expect(ltr ? icon.right : icon.left, ltr ? body.right : body.left);
          expect(button.size, const Size(48, 48));
          expect(button.left, greaterThanOrEqualTo(sheet.left));
          expect(button.right, lessThanOrEqualTo(sheet.right));
          final reset = tester.getRect(find.byType(TextButton));
          expect(reset.overlaps(button), isFalse);
          expect(title.overlaps(button), isFalse);
          // The outer part of the hit target must work, not just the visible X.
          for (final offset in [
            Offset(button.left + 2, button.center.dy),
            Offset(button.right - 2, button.center.dy),
            Offset(button.center.dx, button.top + 2),
            Offset(button.center.dx, button.bottom - 2),
          ]) {
            await tester.tapAt(offset);
            await tester.pump();
          }
          expect(closes, 4);
          expect(resets, 0);
          await tester.tap(find.text('Reset'));
          expect(resets, 1);
          final close = tester.getSemantics(find.byType(IconButton));
          expect(close.tooltip, 'Close');
          expect(close.flagsCollection.isButton, isTrue);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      });
    }
  }

  for (final direction in TextDirection.values) {
    for (final end in [0.0, 8.0, 24.0, 32.0]) {
      testWidgets('header respects directional padding $end in $direction', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: Directionality(
                textDirection: direction,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: 320,
                    child: BottomSheetHeader(
                      title: 'Title',
                      closeLabel: 'Close',
                      onClose: () {},
                      padding: EdgeInsetsDirectional.fromSTEB(24, 6, end, 10),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final header = tester.getRect(find.byType(BottomSheetHeader));
        final title = tester.getRect(find.text('Title'));
        final icon = tester.getRect(find.byIcon(AppIcons.close));
        final button = tester.getRect(find.byType(AppPlainIconButton));
        final ltr = direction == TextDirection.ltr;
        expect(ltr ? title.left - header.left : header.right - title.right, 24);
        expect(
          ltr ? header.right - icon.right : icon.left - header.left,
          end < 14 ? 14 : end,
        );
        expect(button.left, greaterThanOrEqualTo(header.left));
        expect(button.right, lessThanOrEqualTo(header.right));
        expect(button.top - header.top, 6);
        expect(header.bottom - button.bottom, 10);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('busy actions preserve geometry and block repeated commands', (
    tester,
  ) async {
    var commands = 0;
    var busy = false;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return SizedBox(
                width: 300,
                child: AppSheetActions(
                  primaryLabel: 'Cancel',
                  onPrimary: () => commands++,
                  secondaryLabel: 'Delete',
                  onSecondary: () => commands++,
                  destructiveSecondary: true,
                  busy: busy,
                ),
              );
            },
          ),
        ),
      ),
    );
    final before = tester.getRect(find.byType(AppSheetActions));
    update(() => busy = true);
    await tester.pump();
    expect(tester.getRect(find.byType(AppSheetActions)), before);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );
    await tester.tap(find.byType(FilledButton));
    expect(commands, 0);
    update(() => busy = false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    expect(commands, 1);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('sheet actions adapt without shortening labels at $scale', (
      tester,
    ) async {
      var saved = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 272,
                  child: AppSheetActions(
                    primaryLabel: 'Save changes',
                    onPrimary: () => saved++,
                    secondaryLabel: 'Keep editing',
                    onSecondary: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Save changes').hitTestable(), findsOneWidget);
      expect(find.text('Keep editing').hitTestable(), findsOneWidget);
      if (scale == 2) {
        expect(
          tester.getTopLeft(find.byType(OutlinedButton)).dy,
          greaterThan(tester.getBottomLeft(find.byType(FilledButton)).dy),
        );
      }
      await tester.tap(find.text('Save changes'));
      expect(saved, 1);
    });
  }

  testWidgets('action foreground is readable without changing primary fills', (
    tester,
  ) async {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      late Color foreground;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Builder(
            builder: (context) {
              foreground = context.actionForeground;
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final a = foreground.computeLuminance();
      final b = theme.colorScheme.surface.computeLuminance();
      expect(
        (a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05)),
        greaterThanOrEqualTo(4.5),
      );
      if (theme.brightness == Brightness.dark) {
        expect(foreground, isNot(theme.colorScheme.primary));
      }
    }
  });

  Future<void> pump(WidgetTester tester, Widget child, {double scale = 1}) =>
      tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(width: 272, child: child),
              ),
            ),
          ),
        ),
      );

  testWidgets('sheet title geometry does not depend on the close action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await pump(tester, const BottomSheetHeader(title: 'Save Article'));
      expect(
        tester.getSemantics(find.text('Save Article')).flagsCollection.isHeader,
        isTrue,
      );
      final titleRect = tester.getRect(find.text('Save Article'));
      final headerRect = tester.getRect(find.byType(BottomSheetHeader));
      final style = tester.widget<Text>(find.text('Save Article')).style;
      await pump(
        tester,
        BottomSheetHeader(
          title: 'Save Article',
          closeLabel: 'Close',
          onClose: () {},
        ),
      );
      expect(tester.getTopLeft(find.text('Save Article')), titleRect.topLeft);
      expect(
        tester.getSize(find.text('Save Article')).height,
        titleRect.height,
      );
      expect(tester.getRect(find.byType(BottomSheetHeader)), headerRect);
      expect(tester.widget<Text>(find.text('Save Article')).style, style);
      expect(headerRect.height, greaterThanOrEqualTo(48));
      expect(style?.fontSize, AppTheme.light().textTheme.titleMedium?.fontSize);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('long sheet titles grow without truncation at large text', (
    tester,
  ) async {
    await pump(
      tester,
      BottomSheetHeader(
        title: 'A long localized bottom sheet heading',
        closeLabel: 'Close',
        onClose: () {},
      ),
      scale: 2,
    );
    expect(
      tester
          .widget<Text>(find.text('A long localized bottom sheet heading'))
          .maxLines,
      isNull,
    );
    expect(
      tester.getSize(find.byType(BottomSheetHeader)).height,
      greaterThan(48),
    );
    expect(find.byTooltip('Close').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('overflowing header action keeps heading aligned to start', (
    tester,
  ) async {
    for (final direction in TextDirection.values) {
      await pump(
        tester,
        Directionality(
          textDirection: direction,
          child: BottomSheetHeader(
            title: 'Appearance',
            closeLabel: 'Close',
            onClose: () {},
            trailing: TextButton.icon(
              onPressed: () {},
              icon: const Icon(AppIcons.refresh),
              label: const AppButtonLabel('Reset appearance'),
            ),
          ),
        ),
        scale: 2,
      );
      final heading = tester.getRect(find.text('Appearance'));
      final header = tester.getRect(find.byType(BottomSheetHeader));
      expect(
        direction == TextDirection.ltr ? heading.left : heading.right,
        direction == TextDirection.ltr ? header.left : header.right,
      );
      expect(
        tester.getTopLeft(find.byType(TextButton)).dy,
        greaterThanOrEqualTo(heading.bottom),
      );
      expect(find.byTooltip('Close').hitTestable(), findsOneWidget);
      expect(find.text('Reset appearance').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
