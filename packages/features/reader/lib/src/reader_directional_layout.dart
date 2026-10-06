import 'package:flutter/widgets.dart';

TextAlign readerDirectionalTextAlign({required bool pageProgressionRtl}) {
  return pageProgressionRtl ? TextAlign.right : TextAlign.left;
}

TextDirection readerDirectionalTextDirection({
  required bool pageProgressionRtl,
}) {
  return pageProgressionRtl ? TextDirection.rtl : TextDirection.ltr;
}

/// Hidden slide offset for a full-height side panel (contents, search).
///
/// Panels enter from the leading edge of the app locale, not the book's
/// progression direction, so RTL interfaces slide from the right.
Offset readerSidePanelHiddenOffset(TextDirection textDirection) {
  return textDirection == TextDirection.rtl
      ? const Offset(1, 0)
      : const Offset(-1, 0);
}
