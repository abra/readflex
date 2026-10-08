import 'package:flutter/painting.dart';

/// Height of one line of [style] under [scaler], so a small leading mark can
/// centre on a row's first line without measuring the text.
///
/// Exact for styles with an explicit `height` (every app body role); others
/// fall back to a typical 1.2 line height.
double readerTextLineHeight(TextScaler scaler, TextStyle style) {
  return scaler.scale(style.fontSize ?? 14) * (style.height ?? 1.2);
}
