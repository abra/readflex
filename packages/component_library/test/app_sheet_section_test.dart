import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A sheet section is outlined without moving its content: text keeps the
/// sheet's 24dp gutter and a utility target reaches the outline.
void main() {
  const width = 390.0;
  const contentKey = ValueKey('content');

  Future<void> pumpSection(
    WidgetTester tester, {
    String? title,
    EdgeInsets padding = AppSheetSection.defaultPadding,
    Widget child = const SizedBox(key: contentKey, height: 40),
    TextDirection direction = TextDirection.ltr,
    ThemeData? theme,
  }) async {
    tester.view.physicalSize = const Size(width, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? AppTheme.light(),
        home: Directionality(
          textDirection: direction,
          child: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: AppSheetSection(
                title: title,
                padding: padding,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
    // A new theme animates in.
    await tester.pumpAndSettle();
  }

  Finder outline() => find.descendant(
    of: find.byType(AppSheetSection),
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is DecoratedBox &&
          widget.decoration is BoxDecoration &&
          (widget.decoration as BoxDecoration).border != null,
    ),
  );

  testWidgets('the outline sits 10dp from the sheet edges, around the full '
      'height', (tester) async {
    await pumpSection(tester);
    final section = tester.getRect(find.byType(AppSheetSection));
    final box = tester.getRect(outline());
    expect(AppSheetSection.outlineInset, 10);
    expect(box.left, AppSheetSection.outlineInset);
    expect(width - box.right, AppSheetSection.outlineInset);
    expect(box.top, section.top);
    expect(box.bottom, section.bottom);
  });

  testWidgets('content keeps the full width and the default 12dp room', (
    tester,
  ) async {
    await pumpSection(tester);
    final section = tester.getRect(find.byType(AppSheetSection));
    final content = tester.getRect(find.byKey(contentKey));
    expect(content.width, width);
    expect(content.top - section.top, AppSpacing.md);
    expect(section.bottom - content.bottom, AppSpacing.md);
  });

  testWidgets('content that keeps its own room takes no padding', (
    tester,
  ) async {
    await pumpSection(tester, padding: EdgeInsets.zero);
    final section = tester.getRect(find.byType(AppSheetSection));
    final content = tester.getRect(find.byKey(contentKey));
    expect(content.top, section.top);
    expect(content.bottom, section.bottom);
  });

  testWidgets('outline color and radius come from the theme', (tester) async {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      await pumpSection(tester, theme: theme);
      final decoration =
          tester.widget<DecoratedBox>(outline()).decoration as BoxDecoration;
      expect(
        decoration.border,
        Border.all(color: theme.colorScheme.outlineVariant),
      );
      expect(decoration.borderRadius, BorderRadius.circular(AppRadius.md));
      expect(decoration.color, isNull, reason: 'no fill');
    }
  });

  for (final direction in TextDirection.values) {
    testWidgets('the title starts on the 24dp gutter, 8dp above the content '
        '($direction)', (tester) async {
      await pumpSection(tester, title: 'Sentence', direction: direction);
      final title = tester.getRect(find.text('Sentence'));
      final section = tester.getRect(find.byType(AppSheetSection));
      expect(title.top - section.top, AppSpacing.md);
      expect(
        direction == TextDirection.ltr ? title.left : width - title.right,
        AppSpacing.xl,
      );
      expect(
        tester.getRect(find.byKey(contentKey)).top - title.bottom,
        AppSpacing.sm,
      );
    });
  }

  testWidgets('the title is a labelLarge header', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await pumpSection(tester, title: 'Sentence');
      final text = tester.widget<Text>(find.text('Sentence'));
      final context = tester.element(find.text('Sentence'));
      expect(text.style, context.text.labelLarge);
      expect(
        tester.getSemantics(find.text('Sentence')),
        matchesSemantics(label: 'Sentence', isHeader: true),
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('a 48dp action on the gutter reaches the outline', (
    tester,
  ) async {
    var copied = 0;
    await pumpSection(
      tester,
      padding: EdgeInsets.zero,
      child: AppSheetActionRow(
        firstLineStyle: const TextStyle(fontSize: 17, height: 1.45),
        lead: const AppSheetSectionTitle('Word meaning'),
        leadSpacing: AppSpacing.sm,
        minTextRoom: AppSpacing.md,
        action: AppCopyButton(
          onCopy: () async => copied++,
          copyLabel: 'Copy',
          copiedLabel: 'Copied',
          failureLabel: 'Failed',
        ),
        child: const Text(
          'power',
          style: TextStyle(fontSize: 17, height: 1.45),
        ),
      ),
    );
    final copy = tester.getRect(find.widgetWithIcon(IconButton, AppIcons.copy));
    final box = tester.getRect(outline());
    expect(copy.right, box.right);
    expect(width - tester.getRect(find.byIcon(AppIcons.copy)).right, 24);
    // The row's room puts the title 12dp inside the outline.
    expect(
      tester.getRect(find.text('Word meaning')).top - box.top,
      AppSpacing.md,
    );
    await tester.tap(find.byIcon(AppIcons.copy));
    await tester.pump();
    expect(copied, 1);
  });
}
