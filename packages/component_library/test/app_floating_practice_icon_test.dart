import 'dart:ui' as ui;

import 'package:component_library/component_library.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _boundaryKey = ValueKey('icon-capture');
const _captureSize = 64;

Future<ByteData> _capturePixels(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_boundaryKey),
  );
  return (await tester.runAsync(() async {
    final image = await boundary.toImage();
    try {
      return await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    } finally {
      image.dispose();
    }
  }))!;
}

Color _pixelAt(ByteData pixels, int x, int y) {
  final offset = (y * _captureSize + x) * 4;
  return Color.fromARGB(
    pixels.getUint8(offset + 3),
    pixels.getUint8(offset),
    pixels.getUint8(offset + 1),
    pixels.getUint8(offset + 2),
  );
}

double _colorDistance(Color first, Color second) =>
    (first.r - second.r).abs() +
    (first.g - second.g).abs() +
    (first.b - second.b).abs();

void main() {
  setUpAll(() async {
    await (FontLoader('packages/lucide_icons_flutter/Lucide300')..addFont(
          rootBundle.load(
            'packages/lucide_icons_flutter/assets/build_font/LucideVariable-w300.ttf',
          ),
        ))
        .load();
  });

  Future<void> pumpIcon(
    WidgetTester tester, {
    required ThemeData theme,
    required Color background,
    required bool showAura,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Center(
          child: RepaintBoundary(
            key: _boundaryKey,
            child: ColoredBox(
              color: background,
              child: SizedBox.square(
                dimension: _captureSize.toDouble(),
                child: Center(
                  child: AppFloatingPracticeIcon(showAura: showAura),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.binding.transientCallbackCount, 0);
    expect(
      tester.getSize(find.byType(AppFloatingPracticeIcon)),
      const Size.square(32),
    );
    expect(tester.takeException(), isNull);
  }

  for (final theme in [AppTheme.light(), AppTheme.dark()]) {
    for (final showAura in [false, true]) {
      testWidgets('cards obscure content, leaving their surroundings open '
          '${theme.brightness.name}, aura=$showAura', (tester) async {
        for (final background in [Colors.pink, Colors.green]) {
          await pumpIcon(
            tester,
            theme: theme,
            background: background,
            showAura: showAura,
          );
          final pixels = await _capturePixels(tester);

          // One point inside each exposed card, away from the outlines.
          for (final (x, y) in [(36, 35), (30, 23), (22, 29)]) {
            expect(_pixelAt(pixels, x, y), theme.colorScheme.surface);
          }
          // Inside a circular backing but outside the deck: only the soft
          // shadow and optional aura may tint the underlying content.
          final outside = _pixelAt(pixels, 44, 22);
          for (final (actual, expected) in [
            (outside.r, background.r),
            (outside.g, background.g),
            (outside.b, background.b),
          ]) {
            expect(actual, closeTo(expected, showAura ? .15 : .1));
          }
        }
      });
    }

    testWidgets('optional static aura fades beyond the glyph '
        '${theme.brightness.name}', (tester) async {
      await pumpIcon(
        tester,
        theme: theme,
        background: theme.colorScheme.surface,
        showAura: false,
      );
      final plain = await _capturePixels(tester);
      await pumpIcon(
        tester,
        theme: theme,
        background: theme.colorScheme.surface,
        showAura: true,
      );
      final glowing = await _capturePixels(tester);

      // Both samples lie above the 32dp glyph; the outer one must fade
      // towards the untouched background rather than form a solid backing.
      final near = _colorDistance(
        _pixelAt(plain, 32, 12),
        _pixelAt(glowing, 32, 12),
      );
      final far = _colorDistance(
        _pixelAt(plain, 32, 6),
        _pixelAt(glowing, 32, 6),
      );
      expect(far, greaterThan(0));
      expect(near, greaterThan(far));
      expect(_pixelAt(glowing, 32, 2), _pixelAt(plain, 32, 2));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.binding.transientCallbackCount, 0);
    });
  }
}
