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

  group('readerSidePanelHiddenOffset', () {
    test('hides toward the leading edge of the app locale', () {
      expect(
        readerSidePanelHiddenOffset(TextDirection.ltr),
        const Offset(-1, 0),
      );
      expect(
        readerSidePanelHiddenOffset(TextDirection.rtl),
        const Offset(1, 0),
      );
    });
  });
}
