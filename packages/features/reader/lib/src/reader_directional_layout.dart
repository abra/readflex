import 'package:flutter/widgets.dart';

TextAlign readerDirectionalTextAlign({required bool pageProgressionRtl}) {
  return pageProgressionRtl ? TextAlign.right : TextAlign.left;
}

TextDirection readerDirectionalTextDirection({
  required bool pageProgressionRtl,
}) {
  return pageProgressionRtl ? TextDirection.rtl : TextDirection.ltr;
}
