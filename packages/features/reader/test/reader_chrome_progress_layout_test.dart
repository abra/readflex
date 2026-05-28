import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_chrome_progress_layout.dart';

void main() {
  group('readerChromeProgressSlots', () {
    test('keeps chapter title before page indicator for LTR progression', () {
      expect(
        readerChromeProgressSlots(pageProgressionRtl: false),
        const [
          ReaderChromeProgressSlot.chapterTitle,
          ReaderChromeProgressSlot.pageIndicator,
        ],
      );
    });

    test('mirrors page indicator before chapter title for RTL progression', () {
      expect(
        readerChromeProgressSlots(pageProgressionRtl: true),
        const [
          ReaderChromeProgressSlot.pageIndicator,
          ReaderChromeProgressSlot.chapterTitle,
        ],
      );
    });
  });

  group('readerChromeChapterTitleText', () {
    test('uses LTR alignment and direction for LTR progression', () {
      expect(
        readerChromeChapterTitleAlign(pageProgressionRtl: false),
        TextAlign.left,
      );
      expect(
        readerChromeChapterTitleDirection(pageProgressionRtl: false),
        TextDirection.ltr,
      );
    });

    test('uses RTL alignment and direction for RTL progression', () {
      expect(
        readerChromeChapterTitleAlign(pageProgressionRtl: true),
        TextAlign.right,
      );
      expect(
        readerChromeChapterTitleDirection(pageProgressionRtl: true),
        TextDirection.rtl,
      );
    });
  });
}
