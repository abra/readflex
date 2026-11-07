import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';

/// Image previews keep artwork visible; text highlights use their own opacity.
const readerImageSelectionPreviewOpacity = 0.45;

/// Images keep their original colours when the reader theme changes.
Color readerImageHighlightColor(HighlightColor color) => HSLColor.fromColor(
  readerHighlightColor(color, ReaderThemePreset.paper.data),
).withLightness(0.65).toColor();

Color readerHighlightColor(HighlightColor color, ReaderThemeData theme) {
  return switch (color) {
    HighlightColor.yellow => theme.highlightYellow,
    HighlightColor.green => theme.highlightGreen,
    HighlightColor.blue => theme.highlightBlue,
    HighlightColor.pink => theme.highlightPink,
    HighlightColor.purple => theme.highlightPurple,
  };
}

double readerHighlightOpacity(ReaderThemeData theme) {
  return theme.backgroundColor.computeLuminance() >= 0.5 ? 0.82 : 0.72;
}
