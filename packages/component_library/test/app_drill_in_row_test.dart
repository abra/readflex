import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget row, {
    TextDirection direction = TextDirection.ltr,
    double width = 320,
    ThemeData? theme,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: theme ?? AppTheme.light(),
        home: Directionality(
          textDirection: direction,
          child: Scaffold(
            body: Center(
              child: SizedBox(width: width, child: row),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('exposes one button with the title as its label', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var taps = 0;
    await pump(
      tester,
      AppDrillInRow(
        icon: AppIcons.link,
        title: 'Save Article',
        subtitle: 'Paste a web URL',
        onTap: () => taps++,
      ),
    );

    expect(
      tester.getSemantics(find.byType(AppDrillInRow)),
      matchesSemantics(
        label: 'Save Article',
        value: 'Paste a web URL',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    expect(find.byType(Text), findsNWidgets(2));
    await tester.tap(find.text('Save Article'));
    expect(taps, 1);
    semantics.dispose();
  });

  testWidgets('keeps a 48dp minimum height and an 8dp ripple radius', (
    tester,
  ) async {
    await pump(tester, AppDrillInRow(title: 'Language', onTap: () {}));

    expect(tester.getSize(find.byType(AppDrillInRow)).height, 48);
    final ink = tester.widget<InkWell>(find.byType(InkWell));
    expect(ink.borderRadius, BorderRadius.circular(AppRadius.sm));
  });

  testWidgets('padding stays inside the tap target', (tester) async {
    var taps = 0;
    await pump(
      tester,
      AppDrillInRow(
        title: 'Upload Book',
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        onTap: () => taps++,
      ),
    );

    final rect = tester.getRect(find.byType(AppDrillInRow));
    expect(rect.height, greaterThanOrEqualTo(48 + AppSpacing.xl * 2));
    await tester.tapAt(rect.topLeft + const Offset(2, 2));
    expect(taps, 1);
  });

  testWidgets('uses accent icon, onSurface title and muted subtitle', (
    tester,
  ) async {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      await pump(
        tester,
        AppDrillInRow(
          icon: AppIcons.book,
          title: 'Upload Book',
          subtitle: 'EPUB, PDF',
          onTap: () {},
        ),
        theme: theme,
      );
      final context = tester.element(find.byType(AppDrillInRow));
      final colors = context.colors;
      expect(
        tester.widget<Icon>(find.byIcon(AppIcons.book)).color,
        context.actionForeground,
      );
      expect(
        tester.widget<Text>(find.text('Upload Book')).style!.color,
        colors.onSurface,
      );
      expect(
        tester.widget<Text>(find.text('EPUB, PDF')).style!.color,
        colors.onSurfaceVariant,
      );
      expect(
        tester.widget<Icon>(find.byIcon(AppIcons.chevronRight)).color,
        colors.onSurfaceVariant,
      );
      expect(
        tester.widget<Text>(find.text('Upload Book')).style!.fontSize,
        context.text.bodyMedium.fontSize,
      );
    }
  });

  testWidgets('disabled row mutes text and icon, drops ripple and tap', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var taps = 0;
    await pump(
      tester,
      AppDrillInRow(
        icon: AppIcons.link,
        title: 'Save Article',
        enabled: false,
        onTap: () => taps++,
      ),
    );

    final colors = tester.element(find.byType(AppDrillInRow)).colors;
    expect(
      tester.widget<Text>(find.text('Save Article')).style!.color,
      colors.onSurfaceVariant,
    );
    expect(
      tester.widget<Icon>(find.byIcon(AppIcons.link)).color,
      colors.onSurfaceVariant,
    );
    expect(tester.widget<InkWell>(find.byType(InkWell)).onTap, isNull);
    expect(
      tester.getSemantics(find.byType(AppDrillInRow)),
      matchesSemantics(
        label: 'Save Article',
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
      ),
    );
    await tester.tap(find.text('Save Article'));
    expect(taps, 0);
    semantics.dispose();
  });

  testWidgets('iconColor overrides the accent tone', (tester) async {
    await pump(
      tester,
      AppDrillInRow(
        icon: AppIcons.offline,
        iconColor: Colors.orange,
        title: 'Save Article',
        onTap: () {},
      ),
    );
    expect(
      tester.widget<Icon>(find.byIcon(AppIcons.offline)).color,
      Colors.orange,
    );
  });

  testWidgets('leading widget takes the icon slot and its 12dp gap', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var taps = 0;
    for (final direction in TextDirection.values) {
      await pump(
        tester,
        AppDrillInRow(
          leading: const SizedBox.square(
            key: ValueKey('tile'),
            dimension: 40,
          ),
          title: 'File from device',
          subtitle: 'Books, comics and PDF',
          onTap: () => taps++,
        ),
        direction: direction,
      );
      final row = tester.getRect(find.byType(AppDrillInRow));
      final tile = tester.getRect(find.byKey(const ValueKey('tile')));
      final title = tester.getRect(find.text('File from device'));
      if (direction == TextDirection.ltr) {
        expect(tile.left, row.left);
        expect(title.left, tile.right + AppSpacing.md);
      } else {
        expect(tile.right, row.right);
        expect(title.right, tile.left - AppSpacing.md);
      }
      expect(tile.center.dy, closeTo(row.center.dy, 0.5));

      await tester.tapAt(tile.center);
      expect(
        tester.getSemantics(find.byType(AppDrillInRow)),
        matchesSemantics(
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
          label: 'File from device',
          value: 'Books, comics and PDF',
        ),
      );
    }
    expect(taps, 2, reason: 'taps on the leading widget reach the row');
    semantics.dispose();
  });

  testWidgets('chevron follows the layout direction', (tester) async {
    await pump(tester, AppDrillInRow(title: 'Language', onTap: () {}));
    expect(find.byIcon(AppIcons.chevronRight), findsOneWidget);
    final ltrChevron = tester.getRect(find.byIcon(AppIcons.chevronRight));
    final ltrTitle = tester.getRect(find.text('Language'));
    expect(ltrChevron.left, greaterThan(ltrTitle.right));

    await pump(
      tester,
      AppDrillInRow(title: 'Language', onTap: () {}),
      direction: TextDirection.rtl,
    );
    expect(find.byIcon(AppIcons.chevronRight), findsNothing);
    expect(find.byIcon(AppIcons.chevronLeft), findsOneWidget);
    final rtlChevron = tester.getRect(find.byIcon(AppIcons.chevronLeft));
    final rtlTitle = tester.getRect(find.text('Language'));
    expect(rtlChevron.right, lessThan(rtlTitle.left));
  });

  testWidgets('custom trailing replaces the chevron', (tester) async {
    await pump(
      tester,
      AppDrillInRow(
        title: 'Language',
        trailing: const SizedBox(key: ValueKey('trailing'), width: 20),
        onTap: () {},
      ),
    );
    expect(find.byIcon(AppIcons.chevronRight), findsNothing);
    expect(find.byKey(const ValueKey('trailing')), findsOneWidget);
  });

  testWidgets('value sits beside the chevron and wraps when it cannot fit', (
    tester,
  ) async {
    await pump(
      tester,
      AppDrillInRow(title: 'Language', value: 'English', onTap: () {}),
    );
    var title = tester.getRect(find.text('Language'));
    var value = tester.getRect(find.text('English'));
    var chevron = tester.getRect(find.byIcon(AppIcons.chevronRight));
    expect(title.center.dy, closeTo(value.center.dy, 1));
    expect(value.left - title.right, greaterThanOrEqualTo(AppSpacing.md));
    expect(chevron.left - value.right, closeTo(AppSpacing.sm, 1));
    final colors = tester.element(find.byType(AppDrillInRow)).colors;
    expect(
      tester.widget<Text>(find.text('English')).style!.color,
      colors.onSurfaceVariant,
    );

    await pump(
      tester,
      AppDrillInRow(
        title: 'Language',
        value: 'A rather long language name',
        onTap: () {},
      ),
      width: 180,
    );
    title = tester.getRect(find.text('Language'));
    value = tester.getRect(find.text('A rather long language name'));
    chevron = tester.getRect(find.byIcon(AppIcons.chevronRight));
    expect(value.top - title.bottom, greaterThanOrEqualTo(AppSpacing.sm));
    expect(value.center.dy, closeTo(chevron.center.dy, 1));
    expect(
      chevron.right,
      closeTo(tester.getRect(find.byType(AppDrillInRow)).right, 1),
    );
    expect(tester.takeException(), isNull);
  });
}
