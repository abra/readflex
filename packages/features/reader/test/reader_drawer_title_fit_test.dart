import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_drawer_title_fit.dart';

void main() {
  // The test font draws every glyph as a square of the font size, so a
  // 10-glyph title at 20 px is exactly 200 px wide.
  const style = TextStyle(fontSize: 20);

  double? fit(
    String text, {
    required double maxWidth,
    double scale = 1,
    TextStyle textStyle = style,
  }) => readerFittedTitleFontSize(
    text: text,
    style: textStyle,
    textScaler: TextScaler.linear(scale),
    textDirection: TextDirection.ltr,
    maxWidth: maxWidth,
  );

  test('a title that fits keeps its size', () {
    expect(fit('Contents', maxWidth: 200), isNull);
    expect(fit('Содержание', maxWidth: 200), isNull, reason: 'exactly fits');
  });

  test('a slightly long title shrinks just enough to fit', () {
    // 10 glyphs at 2x: 400 px natural in 396 px.
    final size = fit('Содержание', maxWidth: 396, scale: 2)!;
    expect(size, lessThan(40));
    expect(size * 10, lessThanOrEqualTo(396 + 1e-6));
    expect(size, greaterThan(40 * readerDrawerTitleMinFontScale));
  });

  test('a title far too long stops at the minimum and ellipsizes', () {
    final size = fit('A very long sheet title', maxWidth: 100)!;
    expect(size, 20 * readerDrawerTitleMinFontScale);
  });

  test('letter spacing is accounted for in the fitted size', () {
    const spaced = TextStyle(fontSize: 20, letterSpacing: 2);
    // 10 glyphs: 200 px plus 20 px of spacing in 210 px.
    final size = fit('Содержание', maxWidth: 210, textStyle: spaced)!;
    final painter = TextPainter(
      text: TextSpan(
        text: 'Содержание',
        style: spaced.copyWith(fontSize: size),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    expect(painter.width, lessThanOrEqualTo(210 + 0.01));
    painter.dispose();
  });

  test('no room means no shrinking', () {
    expect(fit('Contents', maxWidth: 0), isNull);
  });
}
