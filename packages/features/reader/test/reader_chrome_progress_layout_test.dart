import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_chrome_progress_layout.dart';

void main() {
  group('readerProgressEndLabelMaxWidth', () {
    test('bounds the page label by the row, minus the label gap', () {
      expect(readerProgressEndLabelMaxWidth(300), 300 - readerProgressLabelGap);
      expect(readerProgressEndLabelMaxWidth(500), 500 - readerProgressLabelGap);
    });

    test('never goes negative on a row narrower than the gap', () {
      expect(readerProgressEndLabelMaxWidth(readerProgressLabelGap / 2), 0);
    });

    test('never goes negative', () {
      expect(readerProgressEndLabelMaxWidth(0), 0);
    });
  });

  group('readerProgressLabelsStack', () {
    test('keeps one label line up to 130% text', () {
      for (final scale in [0.85, 1.0, 1.15, 1.3]) {
        expect(
          readerProgressLabelsStack(TextScaler.linear(scale)),
          isFalse,
          reason: '$scale',
        );
      }
    });

    test('gives each label its own line for larger text', () {
      for (final scale in [1.31, 1.5, 2.0, 3.0]) {
        expect(
          readerProgressLabelsStack(TextScaler.linear(scale)),
          isTrue,
          reason: '$scale',
        );
      }
    });
  });
}
