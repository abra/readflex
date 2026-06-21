import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';

import 'reader_color_utils.dart';

Color readerHighlightColor(HighlightColor color, ReaderThemeData theme) {
  return switch (color) {
    HighlightColor.yellow => theme.highlightYellow,
    HighlightColor.green => theme.highlightGreen,
    HighlightColor.blue => theme.highlightBlue,
    HighlightColor.pink => theme.highlightPink,
    HighlightColor.purple => theme.highlightPurple,
  };
}

String readerHighlightCssColor(HighlightColor color, ReaderThemeData theme) {
  return colorToHex(readerHighlightColor(color, theme));
}

String readerHighlightBlendMode(ReaderThemeData theme) {
  return theme.backgroundColor.computeLuminance() >= 0.5
      ? 'multiply'
      : 'lighten';
}

double readerHighlightOpacity(ReaderThemeData theme) {
  return theme.backgroundColor.computeLuminance() >= 0.5 ? 0.82 : 0.72;
}
