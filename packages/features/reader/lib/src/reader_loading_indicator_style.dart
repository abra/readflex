import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';

Color readerLoadingIndicatorColor(ReaderThemeData theme) {
  return theme.primaryTextColor.withValues(alpha: 0.82);
}

Color readerLoadingIndicatorTrackColor(ReaderThemeData theme) {
  final isDark = theme.backgroundColor.computeLuminance() < 0.5;
  final baseColor = isDark ? theme.primaryTextColor : theme.secondaryTextColor;
  return baseColor.withValues(alpha: isDark ? 0.18 : 0.22);
}
