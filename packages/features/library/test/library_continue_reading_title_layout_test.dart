import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_feature/src/library_continue_reading_title_layout.dart';

void main() {
  // The square test font: every glyph is one em wide.
  const style = TextStyle(fontFamily: 'FlutterTest', fontSize: 20);
  const twoWords = 'abcdefgh abcdefgh';

  ContinueReadingTitleLayout resolve(
    String title, {
    required double width,
    double maxHeight = 40,
    TextScaler textScaler = TextScaler.noScaling,
  }) => resolveContinueReadingTitleLayout(
    title: title,
    style: style,
    textScaler: textScaler,
    textDirection: TextDirection.ltr,
    maxWidth: width,
    maxHeight: maxHeight,
  );

  double measureFullTitle(
    String title,
    double fontScale, {
    required double width,
    TextScaler textScaler = TextScaler.noScaling,
    int? maxLines,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: title,
        style: style.copyWith(fontSize: style.fontSize! * fontScale),
      ),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
      maxLines: maxLines,
    );
    try {
      painter.layout(maxWidth: width);
      expect(
        painter.didExceedMaxLines,
        isFalse,
        reason: 'the entire title fits',
      );
      return painter.height;
    } finally {
      painter.dispose();
    }
  }

  group('resolveContinueReadingTitleLayout', () {
    test('keeps the full font size when the entire title fits', () {
      final layout = resolve(twoWords, width: 160);
      expect(layout.fontScale, 1);
      expect(
        measureFullTitle(
          twoWords,
          layout.fontScale,
          width: 160,
          maxLines: layout.maxLines,
        ),
        lessThanOrEqualTo(40),
      );
    });

    test('chooses the largest font that fits the complete title', () {
      final layout = resolve(twoWords, width: 150);
      expect(layout.fontScale, lessThan(1));
      expect(
        measureFullTitle(
          twoWords,
          layout.fontScale,
          width: 150,
          maxLines: layout.maxLines,
        ),
        lessThanOrEqualTo(40),
      );
      expect(
        measureFullTitle(twoWords, layout.fontScale + 0.01, width: 150),
        greaterThan(40),
        reason: 'a larger font would put part of the title outside the budget',
      );
    });

    test('fits the available height as well as the width', () {
      final layout = resolve(twoWords, width: 160, maxHeight: 32);
      expect(
        layout.fontScale,
        lessThan(resolve(twoWords, width: 160).fontScale),
      );
      expect(
        measureFullTitle(
          twoWords,
          layout.fontScale,
          width: 160,
          maxLines: layout.maxLines,
        ),
        lessThanOrEqualTo(32),
      );
      expect(
        measureFullTitle(twoWords, layout.fontScale + 0.01, width: 160),
        greaterThan(32),
      );
    });

    test(
      'continues shrinking when the complete title needs a smaller font',
      () {
        final title = List.filled(50, 'ab').join(' ');
        final layout = resolve(title, width: 100);
        expect(layout.fontScale, greaterThan(0));
        expect(layout.fontScale, lessThan(0.8));
        expect(layout.maxLines, greaterThan(2));
        expect(
          measureFullTitle(
            title,
            layout.fontScale,
            width: 100,
            maxLines: layout.maxLines,
          ),
          lessThanOrEqualTo(40),
        );
      },
    );

    test('uses additional lines at full size when the height permits', () {
      const title = 'ab ab ab ab ab';
      final layout = resolve(title, width: 80, maxHeight: 100);
      expect(layout.fontScale, 1);
      expect(layout.maxLines, greaterThan(2));
      expect(
        measureFullTitle(
          title,
          layout.fontScale,
          width: 80,
          maxLines: layout.maxLines,
        ),
        lessThanOrEqualTo(100),
      );
    });

    test('measures the whole title with the system text scaler', () {
      final scaled = resolve(
        twoWords,
        width: 300,
        maxHeight: 80,
        textScaler: const TextScaler.linear(2),
      );
      final unscaled = resolve(twoWords, width: 150);
      expect(scaled.fontScale, closeTo(unscaled.fontScale, 0.001));
      expect(
        measureFullTitle(
          twoWords,
          scaled.fontScale,
          width: 300,
          textScaler: const TextScaler.linear(2),
          maxLines: scaled.maxLines,
        ),
        lessThanOrEqualTo(80),
      );
    });

    test('an empty title keeps the full size', () {
      final layout = resolve('', width: 100);
      expect(layout.fontScale, 1);
      expect(layout.maxLines, greaterThan(0));
    });
  });
}
