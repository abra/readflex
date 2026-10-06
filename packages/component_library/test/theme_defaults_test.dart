import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards against global theme defaults leaking into surfaces that use a
/// different idiom (full-bleed rows, filled buttons, menus).
void main() {
  for (final theme in [AppTheme.light(), AppTheme.dark()]) {
    final name = theme.brightness.name;

    test('$name: list tiles have no themed shape, so full-bleed rows stay '
        'rectangular', () {
      expect(theme.listTileTheme.shape, isNull);
    });

    test('$name: menus share the small popup radius', () {
      final shape = theme.menuTheme.style?.shape?.resolve({});
      expect(shape, isA<RoundedRectangleBorder>());
      expect(
        (shape! as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(AppRadius.sm),
      );
    });

    testWidgets('$name: a busy filled button shows its spinner in the '
        'button foreground, not primary-on-primary', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () {},
                child: const ButtonLoadingIndicator(),
              ),
            ),
          ),
        ),
      );
      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(indicator.color, theme.colorScheme.onPrimary);
      expect(indicator.color, isNot(theme.colorScheme.primary));
    });

    testWidgets('$name: a plain icon button spinner takes the given colour', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Center(
              child: AppPlainIconButton(
                iconWidget: const ButtonLoadingIndicator(),
                tooltip: 'Saving',
                onPressed: () {},
                color: Colors.teal,
              ),
            ),
          ),
        ),
      );
      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(indicator.color, Colors.teal);
    });

    testWidgets('$name: a selected ListTile paints a rectangular fill edge '
        'to edge', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: ListTile(
              selected: true,
              selectedTileColor: theme.colorScheme.selectedControlBackground,
              title: const Text('Row'),
              onTap: () {},
            ),
          ),
        ),
      );
      final ink = tester.widget<Ink>(find.byType(Ink));
      final shape = (ink.decoration! as ShapeDecoration).shape;
      // With no themed shape, Flutter clips the fill to a plain Border.
      expect(shape, isNot(isA<RoundedRectangleBorder>()));
      expect(shape, isA<Border>());
      expect(tester.getSize(find.byType(ListTile)).width, 800);
    });
  }

  testWidgets('light scroll-edge fade is visible on a pale surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: ScrollEdgeFade(edge: ScrollFadeEdge.top, visible: true),
        ),
      ),
    );
    final box = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(ScrollEdgeFade),
        matching: find.byType(DecoratedBox),
      ),
    );
    final gradient =
        (box.decoration as BoxDecoration).gradient as LinearGradient;
    expect(gradient.colors.first.a, greaterThanOrEqualTo(0.14));
  });

  testWidgets('horizontal scroll fade dissolves into the scaffold background '
      'instead of darkening', (tester) async {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(
            body: ScrollEdgeFade(edge: ScrollFadeEdge.end, visible: true),
          ),
        ),
      );
      // MaterialApp animates theme changes between iterations.
      await tester.pumpAndSettle();
      final box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(ScrollEdgeFade),
          matching: find.byType(DecoratedBox),
        ),
      );
      final gradient =
          (box.decoration as BoxDecoration).gradient as LinearGradient;
      expect(gradient.colors.first, theme.scaffoldBackgroundColor);
      expect(gradient.colors.last.a, 0);
    }
  });

  testWidgets('horizontal scroll fade uses the given surface colour', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: ScrollEdgeFade(
            edge: ScrollFadeEdge.start,
            visible: true,
            surfaceColor: Colors.green,
          ),
        ),
      ),
    );
    final box = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(ScrollEdgeFade),
        matching: find.byType(DecoratedBox),
      ),
    );
    final gradient =
        (box.decoration as BoxDecoration).gradient as LinearGradient;
    expect(gradient.colors.first, Colors.green);
  });

  testWidgets('filter chip label and count use onSurfaceVariant at full '
      'alpha when unselected', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: AppFilterChip(
            label: 'Books',
            count: 3,
            selected: false,
            onTap: () {},
          ),
        ),
      ),
    );
    final context = tester.element(find.byType(AppFilterChip));
    expect(
      tester.widget<Text>(find.text('Books')).style?.color,
      context.colors.onSurfaceVariant,
    );
    expect(
      tester.widget<Text>(find.text('3')).style?.color,
      context.colors.onSurfaceVariant,
    );
  });

  testWidgets('ErrorState stacks the filled Retry above the secondary when '
      'labels do not fit', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SizedBox(
            width: 220,
            child: ErrorState(
              message: 'Failed',
              retryLabel: 'Try loading this book again',
              onRetry: () {},
              secondaryLabel: 'Return to the library',
              onSecondary: () {},
            ),
          ),
        ),
      ),
    );
    final retry = tester.getRect(find.byType(FilledButton));
    final secondary = tester.getRect(find.byType(OutlinedButton));
    expect(retry.bottom, lessThanOrEqualTo(secondary.top));
    expect(retry.width, closeTo(secondary.width, 0.5));
  });

  testWidgets('lexical row keeps the ambient direction for part of speech '
      'while the reading follows the headword', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: AppLexicalMetadataRow(
            reading: 'طاقة',
            partOfSpeech: 'noun',
            textDirection: TextDirection.rtl,
          ),
        ),
      ),
    );
    final wrap = tester.widget<Wrap>(find.byType(Wrap));
    expect(wrap.textDirection, isNull);
    expect(
      tester.widget<Text>(find.text('طاقة')).textDirection,
      TextDirection.rtl,
    );
    expect(
      tester.getTopLeft(find.text('طاقة')).dx,
      lessThan(tester.getTopLeft(find.text('noun')).dx),
    );
  });

  testWidgets('drill-in row merges a value style for previews', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: AppDrillInRow(
            title: 'Font',
            value: 'Literata',
            valueStyle: const TextStyle(fontFamily: 'Literata'),
            onTap: () {},
          ),
        ),
      ),
    );
    final context = tester.element(find.byType(AppDrillInRow));
    final style = tester.widget<Text>(find.text('Literata')).style!;
    expect(style.fontFamily, 'Literata');
    expect(style.color, context.colors.onSurfaceVariant);
  });

  testWidgets('horizontal edge fades are thin on the main axis and mirror in '
      'RTL', (tester) async {
    for (final direction in [TextDirection.ltr, TextDirection.rtl]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Directionality(
            textDirection: direction,
            child: const Scaffold(
              body: SizedBox(
                width: 300,
                height: 48,
                child: Stack(
                  children: [
                    PositionedDirectional(
                      end: 0,
                      top: 0,
                      bottom: 0,
                      child: ScrollEdgeFade(
                        edge: ScrollFadeEdge.end,
                        visible: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      final fade = tester.getRect(find.byType(ScrollEdgeFade));
      expect(fade.width, 18);
      expect(fade.height, 48);
      final gradient =
          (tester
                          .widget<DecoratedBox>(
                            find.descendant(
                              of: find.byType(ScrollEdgeFade),
                              matching: find.byType(DecoratedBox),
                            ),
                          )
                          .decoration
                      as BoxDecoration)
                  .gradient!
              as LinearGradient;
      expect(gradient.begin, AlignmentDirectional.centerEnd);
      expect(
        direction == TextDirection.ltr ? fade.right : fade.left,
        direction == TextDirection.ltr ? 300 : 0,
      );
    }
  });

  testWidgets('sheet action row can follow its content direction', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: AppSheetActionRow(
              textDirection: TextDirection.ltr,
              action: const Icon(AppIcons.copy),
              child: const Text('power'),
            ),
          ),
        ),
      ),
    );
    // LTR content in an RTL app: the action trails the text on the right.
    expect(
      tester.getTopLeft(find.byIcon(AppIcons.copy)).dx,
      greaterThan(tester.getTopRight(find.text('power')).dx - 1),
    );
  });
}
