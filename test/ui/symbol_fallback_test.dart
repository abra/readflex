import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadUiFonts);

  for (final brightness in Brightness.values) {
    final theme = brightness == Brightness.light
        ? AppTheme.light()
        : AppTheme.dark();
    final style = theme.textTheme.bodyMedium!.copyWith(fontSize: 32);

    for (final symbol in ['\u267E', '\u267C', '\u262F']) {
      test(
        'symbol ${symbol.runes.single} uses fallback ($brightness)',
        () async {
          // Compare the painted glyph, not just string contents or font names.
          final expected = await _render(
            symbol,
            style.copyWith(fontFamily: AppTypography.fontFamilySymbols),
          );
          expect(await _render(symbol, style), orderedEquals(expected));
          expect(
            await _render('\uFFFD', style),
            isNot(orderedEquals(expected)),
          );
        },
      );
    }

    test(
      'fallback preserves Latin and Cyrillic typography ($brightness)',
      () async {
        const text = 'Readflex 123 / Перевод';
        expect(
          await _render(text, style),
          orderedEquals(
            await _render(text, style.copyWith(fontFamilyFallback: const [])),
          ),
        );
      },
    );
  }
}

Future<Uint8List> _render(String text, TextStyle style) async {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout();
  final recorder = ui.PictureRecorder();
  // Align baselines so font ascent/descent differences do not hide a wrong glyph.
  painter.paint(
    Canvas(recorder),
    Offset(
      0,
      60 - painter.computeDistanceToActualBaseline(TextBaseline.alphabetic),
    ),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(480, 96);
  try {
    final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    return Uint8List.fromList(data.buffer.asUint8List());
  } finally {
    image.dispose();
    picture.dispose();
    painter.dispose();
  }
}
