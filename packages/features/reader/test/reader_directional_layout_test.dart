import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_directional_layout.dart';

void main() {
  group('readerDirectionalText', () {
    test('uses left-to-right text metrics for LTR progression', () {
      expect(
        readerDirectionalTextAlign(pageProgressionRtl: false),
        TextAlign.left,
      );
      expect(
        readerDirectionalTextDirection(pageProgressionRtl: false),
        TextDirection.ltr,
      );
    });

    test('uses right-to-left text metrics for RTL progression', () {
      expect(
        readerDirectionalTextAlign(pageProgressionRtl: true),
        TextAlign.right,
      );
      expect(
        readerDirectionalTextDirection(pageProgressionRtl: true),
        TextDirection.rtl,
      );
    });
  });

  group('readerDirectionalContentPadding', () {
    test('keeps start inset on the left for LTR progression', () {
      expect(
        readerDirectionalContentPadding(
          pageProgressionRtl: false,
          start: 24,
          end: 8,
          top: 2,
          bottom: 4,
        ),
        const EdgeInsets.only(left: 24, right: 8, top: 2, bottom: 4),
      );
    });

    test('moves start inset to the right for RTL progression', () {
      expect(
        readerDirectionalContentPadding(
          pageProgressionRtl: true,
          start: 24,
          end: 8,
          top: 2,
          bottom: 4,
        ),
        const EdgeInsets.only(left: 8, right: 24, top: 2, bottom: 4),
      );
    });
  });
}
