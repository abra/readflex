import 'package:flutter/widgets.dart';

TextAlign readerDirectionalTextAlign({required bool pageProgressionRtl}) {
  return pageProgressionRtl ? TextAlign.right : TextAlign.left;
}

TextDirection readerDirectionalTextDirection({
  required bool pageProgressionRtl,
}) {
  return pageProgressionRtl ? TextDirection.rtl : TextDirection.ltr;
}

EdgeInsets readerDirectionalContentPadding({
  required bool pageProgressionRtl,
  required double start,
  required double end,
  double top = 0,
  double bottom = 0,
}) {
  return EdgeInsets.only(
    left: pageProgressionRtl ? end : start,
    right: pageProgressionRtl ? start : end,
    top: top,
    bottom: bottom,
  );
}
