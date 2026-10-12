import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A large heading shrinks just enough to keep its longest word whole.
void main() {
  // The test font draws every glyph as a square of the font size: a 10-glyph
  // word at 24 px is 240 px wide.
  const heading = TextStyle(fontSize: 24, height: 1.2, letterSpacing: 0);
  const word = 'possession';

  TextStyle fit(
    String text, {
    double maxWidth = 200,
    double minFontSize = 15,
    TextScaler textScaler = TextScaler.noScaling,
    TextStyle style = heading,
  }) => appFitLongestWord(
    style,
    text: text,
    maxWidth: maxWidth,
    minFontSize: minFontSize,
    textScaler: textScaler,
    textDirection: TextDirection.ltr,
  );

  double widestWord(String text, TextStyle style, TextScaler scaler) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();
    final width = painter.minIntrinsicWidth;
    painter.dispose();
    return width;
  }

  test('a word that fits keeps the style itself', () {
    expect(fit(word, maxWidth: 240), same(heading));
  });

  test('text that only wraps between words keeps its size', () {
    // Each 4-glyph word is 96 px; the whole text is far wider than 200 px.
    expect(fit(List.filled(10, 'word').join(' ')), same(heading));
  });

  test('a long word shrinks just enough to fit', () {
    final style = fit(word);
    expect(style.fontSize, lessThanOrEqualTo(20));
    expect(style.fontSize, greaterThan(20 - 0.25));
    expect(
      widestWord(word, style, TextScaler.noScaling),
      lessThanOrEqualTo(200),
    );
    // Only the size changes.
    expect(style.copyWith(fontSize: 24), heading);
  });

  test('only the longest word decides', () {
    final style = fit('a $word b');
    expect(style.fontSize, fit(word).fontSize);
  });

  test('never below the minimum size, where the word may break', () {
    expect(fit(word, maxWidth: 50).fontSize, 15);
  });

  test('a style already at the minimum is left alone', () {
    expect(fit(word, maxWidth: 50, minFontSize: 24), same(heading));
  });

  test('measures at the text scale and returns the unscaled size', () {
    // At 2x a 10-glyph word fits 200 px at 10 px unscaled.
    final style = fit(
      word,
      minFontSize: 8,
      textScaler: const TextScaler.linear(2),
    );
    expect(style.fontSize, lessThanOrEqualTo(10));
    expect(style.fontSize, greaterThan(10 - 0.25));
  });

  test('follows a nonlinear text scaler', () {
    const scaler = _OffsetScaler(10);
    final style = fit(word, minFontSize: 5, textScaler: scaler);
    // 10 glyphs at (size + 10) px fit 200 px up to size 10.
    expect(style.fontSize, lessThanOrEqualTo(10));
    expect(style.fontSize, greaterThan(10 - 0.25));
    expect(widestWord(word, style, scaler), lessThanOrEqualTo(200));
  });

  group('appFitSelectableText', () {
    Future<TextStyle> fitIn(
      WidgetTester tester, {
      required double boxWidth,
      TextScaler textScaler = TextScaler.noScaling,
    }) async {
      late TextStyle result;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: MediaQuery(
            data: MediaQueryData(textScaler: textScaler),
            child: Builder(
              builder: (context) {
                result = appFitSelectableText(
                  context,
                  heading,
                  text: word,
                  boxWidth: boxWidth,
                  textDirection: TextDirection.ltr,
                );
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      return result;
    }

    testWidgets('a word that fits the box keeps the style', (tester) async {
      // 240 px of word and the caret margin.
      expect(await fitIn(tester, boxWidth: 243), same(heading));
    });

    testWidgets('the caret margin is taken off the box', (tester) async {
      final style = await fitIn(tester, boxWidth: 240);
      expect(style.fontSize, lessThan(24));
      expect(style.fontSize! * word.length, lessThanOrEqualTo(237));
    });

    testWidgets('never below metadata size, at the context text scale', (
      tester,
    ) async {
      final style = await fitIn(
        tester,
        boxWidth: 100,
        textScaler: const TextScaler.linear(2),
      );
      final context = tester.element(find.byType(SizedBox).last);
      expect(style.fontSize, context.text.bodyMedium.fontSize);
    });
  });
}

/// Adds a fixed amount to every size, like a nonlinear accessibility curve.
class _OffsetScaler extends TextScaler {
  const _OffsetScaler(this.offset);

  final double offset;

  @override
  double scale(double fontSize) => fontSize + offset;

  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => 1;

  @override
  TextScaler clamp({double minScaleFactor = 0, double maxScaleFactor = 1e9}) =>
      this;
}
