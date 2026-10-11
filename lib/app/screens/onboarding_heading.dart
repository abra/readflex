import 'dart:math' as math;

import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';

/// Smallest share of the heading role the onboarding heading may shrink to.
const double kOnboardingHeadingMinFontScale = 0.6;

const double _fontScaleStep = 0.02;

final _whitespace = RegExp(r'\s+');

/// Characters a line may break around anywhere: CJK punctuation, kana,
/// ideographs and fullwidth forms. Korean is left out; it breaks at spaces.
final _breaksAnywhere = RegExp(
  '[\u3000-\u30FF\u3400-\u4DBF\u4E00-\u9FFF\uF900-\uFAFF\uFF00-\uFFEF]',
);

/// The onboarding heading, centered and marked as a header.
///
/// It wraps between words like any text. When a single unbreakable piece is
/// wider than the line, such as "Willkommen" at 200% text on a 320dp phone,
/// it shrinks just enough for that piece to fit instead of breaking it
/// mid-word.
class OnboardingHeading extends StatelessWidget {
  const OnboardingHeading(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final style = context.text.headlineSmall;
    final textScaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);
    final locale = Localizations.maybeLocaleOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = onboardingHeadingFontScale(
          text: text,
          style: style,
          textScaler: textScaler,
          textDirection: textDirection,
          maxWidth: constraints.maxWidth,
          locale: locale,
        );
        return Semantics(
          header: true,
          child: Text(
            text,
            style: scale == 1
                ? style
                : style.copyWith(fontSize: style.fontSize! * scale),
            textAlign: TextAlign.center,
          ),
        );
      },
    );
  }
}

/// The font scale at which the widest unbreakable piece of [text] fits in
/// [maxWidth]: 1 when it already fits, never below
/// [kOnboardingHeadingMinFontScale].
///
/// A piece is a space-separated word, except that CJK characters are pieces
/// of their own: lines break between them, so Chinese and Japanese never
/// shrink. The pieces are measured directly rather than through the
/// paragraph's minimum intrinsic width, which treats a run of ideographs as
/// one word wherever word segmentation lacks CJK data.
@visibleForTesting
double onboardingHeadingFontScale({
  required String text,
  required TextStyle style,
  required TextScaler textScaler,
  required TextDirection textDirection,
  required double maxWidth,
  Locale? locale,
}) {
  if (!maxWidth.isFinite || maxWidth <= 0) return 1;
  final pieces = onboardingHeadingPieces(text).toList();
  if (pieces.isEmpty) return 1;

  final painter = TextPainter(
    textDirection: textDirection,
    textScaler: textScaler,
    locale: locale,
    maxLines: 1,
  );
  try {
    double widestAt(double scale) {
      final scaled = scale == 1
          ? style
          : style.copyWith(fontSize: style.fontSize! * scale);
      var widest = 0.0;
      for (final piece in pieces) {
        painter
          ..text = TextSpan(text: piece, style: scaled)
          ..layout();
        widest = math.max(widest, painter.width);
      }
      return widest;
    }

    final widest = widestAt(1);
    if (widest <= maxWidth) return 1;
    // Width is close to linear in font size; the loop absorbs rounding.
    var scale = math.max(kOnboardingHeadingMinFontScale, maxWidth / widest);
    while (scale > kOnboardingHeadingMinFontScale &&
        widestAt(scale) > maxWidth) {
      scale = math.max(kOnboardingHeadingMinFontScale, scale - _fontScaleStep);
    }
    return scale;
  } finally {
    painter.dispose();
  }
}

/// The pieces of [text] a line never breaks inside; see
/// [onboardingHeadingFontScale].
@visibleForTesting
Iterable<String> onboardingHeadingPieces(String text) sync* {
  for (final word in text.split(_whitespace)) {
    final run = StringBuffer();
    for (final rune in word.runes) {
      final char = String.fromCharCode(rune);
      if (_breaksAnywhere.hasMatch(char)) {
        if (run.isNotEmpty) {
          yield run.toString();
          run.clear();
        }
        yield char;
      } else {
        run.write(char);
      }
    }
    if (run.isNotEmpty) yield run.toString();
  }
}
