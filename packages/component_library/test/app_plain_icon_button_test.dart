import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('default glyph follows medium sizes while targets stay 48dp', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: AppPlainIconButton(
              icon: AppIcons.close,
              tooltip: 'Close',
              onPressed: () {},
            ),
          ),
        ),
      ),
    );
    for (final (size, glyph) in const [
      (Size(390, 844), 20.0),
      (Size(599, 900), 20.0),
      (Size(600, 479), 20.0),
      (Size(600, 480), 24.0),
      (Size(800, 1280), 24.0),
      (Size(844, 390), 20.0),
    ]) {
      tester.view.physicalSize = size;
      await tester.pump();
      expect(tester.widget<Icon>(find.byIcon(AppIcons.close)).size, glyph);
      expect(tester.getSize(find.byType(IconButton)), const Size(48, 48));
      expect(tester.takeException(), isNull);
    }
  });

  for (final explicitSize in [20.0, 24.0, 32.0]) {
    testWidgets('explicit $explicitSize glyph overrides every window', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Center(
              child: AppPlainIconButton(
                icon: AppIcons.close,
                iconSize: explicitSize,
                tooltip: 'Close',
                onPressed: () {},
              ),
            ),
          ),
        ),
      );
      for (final size in const [
        Size(390, 844),
        Size(800, 1280),
        Size(600, 480),
        Size(844, 390),
      ]) {
        tester.view.physicalSize = size;
        await tester.pump();
        expect(
          tester.widget<Icon>(find.byIcon(AppIcons.close)).size,
          explicitSize,
        );
        expect(tester.getSize(find.byType(IconButton)), const Size(48, 48));
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('custom glyph retains its own bounds across window changes', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: AppPlainIconButton(
              tooltip: 'Bookmark',
              iconWidget: const SizedBox.square(
                key: ValueKey('customGlyph'),
                dimension: 24,
              ),
              onPressed: () {},
            ),
          ),
        ),
      ),
    );
    for (final size in const [Size(390, 844), Size(800, 1280)]) {
      tester.view.physicalSize = size;
      await tester.pump();
      expect(
        tester.getSize(find.byKey(const ValueKey('customGlyph'))),
        const Size(24, 24),
      );
      expect(tester.getSize(find.byType(IconButton)), const Size(48, 48));
    }
  });
}
