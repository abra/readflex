import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// WCAG AA for body text drawn over a highlighted quote.
const readerHighlightQuoteMinContrast = 4.5;

const _alphaStep = 0.02;
const _cacheLimit = 32;
final _cache = <(Color, Color, Color, double), Color>{};

/// Opaque fill painted under a saved quote in the Contents drawer.
///
/// [highlight] starts at the page's own highlight [opacity] premixed over the
/// drawer [surface], then fades toward the surface until [text] keeps
/// [readerHighlightQuoteMinContrast]. The reader theme and the app theme are
/// chosen separately, so a dark theme's deep highlight on a light drawer (or a
/// pastel one on a dark drawer) is lightened rather than left unreadable.
/// Returns [surface] when no tint keeps the contrast. Results are memoized:
/// a list builds the same few colour pairs for every row.
Color readerHighlightQuoteBackground({
  required Color highlight,
  required Color surface,
  required Color text,
  required double opacity,
}) {
  final key = (highlight, surface, text, opacity);
  final cached = _cache[key];
  if (cached != null) return cached;

  var alpha = opacity.clamp(0.0, 1.0);
  var background = _premix(highlight, surface, alpha);
  while (alpha > 0 &&
      readerContrastRatio(text, background) < readerHighlightQuoteMinContrast) {
    alpha = math.max(0, alpha - _alphaStep);
    background = _premix(highlight, surface, alpha);
  }
  if (_cache.length >= _cacheLimit) _cache.clear();
  return _cache[key] = background;
}

/// WCAG contrast ratio between two opaque colours.
double readerContrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

Color _premix(Color highlight, Color surface, double alpha) =>
    Color.alphaBlend(highlight.withValues(alpha: alpha), surface);
