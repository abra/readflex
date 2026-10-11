import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_feature/src/library_continue_reading_title_layout.dart';

void main() {
  // The square test font: every glyph is one em wide.
  const style = TextStyle(fontFamily: 'FlutterTest', fontSize: 20);
  const threeWords = 'abcdefgh abcdefgh abcdefgh';

  ContinueReadingTitleLayout resolve(
    String title, {
    required double width,
    TextScaler textScaler = TextScaler.noScaling,
  }) => resolveContinueReadingTitleLayout(
    title: title,
    style: style,
    textScaler: textScaler,
    textDirection: TextDirection.ltr,
    maxWidth: width,
  );

  group('resolveContinueReadingTitleLayout', () {
    test('keeps the full size while the title fits in three lines', () {
      final layout = resolve(threeWords, width: 160);
      expect(layout.fontScale, 1);
      expect(layout.truncated, isFalse);
    });

    test('shrinks just enough for three lines to fit', () {
      // 8 glyphs of 18px fit 150px; of 19px they do not.
      final layout = resolve(threeWords, width: 150);
      expect(layout.fontScale, closeTo(.9, .001));
      expect(layout.truncated, isFalse);
    });

    test('stops at the minimum size and ellipsizes the rest', () {
      final layout = resolve(List.filled(50, 'ab').join(' '), width: 100);
      expect(layout.fontScale, kContinueReadingTitleMinFontScale);
      expect(layout.truncated, isTrue);
    });

    test('fits at the minimum size without truncating', () {
      // 8 glyphs of 16px fit 128px.
      final layout = resolve(threeWords, width: 128);
      expect(layout.fontScale, kContinueReadingTitleMinFontScale);
      expect(layout.truncated, isFalse);
    });

    test('measures with the text scaler', () {
      final scaled = resolve(
        threeWords,
        width: 300,
        textScaler: const TextScaler.linear(2),
      );
      final unscaled = resolve(threeWords, width: 150);
      expect(scaled.fontScale, unscaled.fontScale);
      expect(scaled.truncated, unscaled.truncated);
    });

    test('an empty title keeps the full size', () {
      final layout = resolve('', width: 100);
      expect(layout.fontScale, 1);
      expect(layout.truncated, isFalse);
    });
  });
}
