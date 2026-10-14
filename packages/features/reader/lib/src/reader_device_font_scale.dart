import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';

/// Shortest window side, in logical pixels, from which a window counts as
/// tablet-sized. Like Android's `sw600dp` it ignores orientation, so rotating
/// never resizes the text, and phones stay phones in landscape (their shortest
/// side is at most about 440).
const _tabletMinShortestSide = 600.0;

/// Book text in tablet-sized windows is 12.5% larger than on phones: 18px
/// instead of 16px at the reader's 100%. A tablet is held further away, and
/// the 32em line measure grows with the text, so lines keep their length in
/// characters.
const _tabletTextScale = 1.125;

const _androidPhoneMinSide = 360.0;
const _androidPhoneScale = 1.12;
const _androidTabletScale = 1.04;

/// Renderer-only multiplier for the reader's base font size.
///
/// User-facing reader size stays at 100%; this multiplier is applied only when
/// building FoliateStyle. It combines two independent corrections:
/// - Android WebViews render text smaller than iOS at the same reader
///   preference, so Android phones get up to 12% more and Android tablets 4%.
/// - Tablet-sized windows get 12.5% more on every platform.
///
/// [viewportSize] is the window size, so a narrow Split View or Slide Over
/// window reads like a phone.
double readerDeviceFontScale({
  required TargetPlatform platform,
  required Size viewportSize,
}) {
  final shortestSide = viewportSize.shortestSide;
  return _platformScale(platform, shortestSide) * _windowScale(shortestSide);
}

double _platformScale(TargetPlatform platform, double shortestSide) {
  if (platform != TargetPlatform.android) return 1.0;
  // An unknown (zero) window gets the phone correction too.
  if (shortestSide <= _androidPhoneMinSide) return _androidPhoneScale;
  if (shortestSide >= _tabletMinShortestSide) return _androidTabletScale;

  final t =
      (shortestSide - _androidPhoneMinSide) /
      (_tabletMinShortestSide - _androidPhoneMinSide);
  return _androidPhoneScale + (_androidTabletScale - _androidPhoneScale) * t;
}

double _windowScale(double shortestSide) =>
    shortestSide >= _tabletMinShortestSide ? _tabletTextScale : 1.0;
