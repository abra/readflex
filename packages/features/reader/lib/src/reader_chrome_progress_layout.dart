import 'package:flutter/widgets.dart';

enum ReaderChromeProgressSlot { chapterTitle, pageIndicator }

List<ReaderChromeProgressSlot> readerChromeProgressSlots({
  required bool pageProgressionRtl,
}) {
  return pageProgressionRtl
      ? const [
          ReaderChromeProgressSlot.pageIndicator,
          ReaderChromeProgressSlot.chapterTitle,
        ]
      : const [
          ReaderChromeProgressSlot.chapterTitle,
          ReaderChromeProgressSlot.pageIndicator,
        ];
}

TextAlign readerChromeChapterTitleAlign({
  required bool pageProgressionRtl,
}) {
  return pageProgressionRtl ? TextAlign.right : TextAlign.left;
}

TextDirection readerChromeChapterTitleDirection({
  required bool pageProgressionRtl,
}) {
  return pageProgressionRtl ? TextDirection.rtl : TextDirection.ltr;
}
