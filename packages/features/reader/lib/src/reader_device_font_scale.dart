import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';

const _androidPhoneMinSide = 360.0;
const _androidTabletMinSide = 600.0;
const _androidPhoneScale = 1.12;
const _androidTabletScale = 1.04;

/// Renderer-only correction for platform WebView text rendering differences.
///
/// User-facing reader size stays at 100%; this multiplier is applied only when
/// building FoliateStyle so Android phones do not render the default book text
/// noticeably smaller than iOS at the same reader preference.
double readerDeviceFontScale({
  required TargetPlatform platform,
  required Size viewportSize,
}) {
  if (platform != TargetPlatform.android) return 1.0;

  final shortestSide = viewportSize.shortestSide;
  if (shortestSide <= 0) return _androidPhoneScale;
  if (shortestSide <= _androidPhoneMinSide) return _androidPhoneScale;
  if (shortestSide >= _androidTabletMinSide) return _androidTabletScale;

  final t =
      (shortestSide - _androidPhoneMinSide) /
      (_androidTabletMinSide - _androidPhoneMinSide);
  return _androidPhoneScale + (_androidTabletScale - _androidPhoneScale) * t;
}
