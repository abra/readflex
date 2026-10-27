import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

const double _tintAlpha = 0.35;

/// The highlight colour as a translucent tint under quoted text.
Color practiceHighlightTint(BuildContext context, HighlightColor color) {
  final palette = context.appColors;
  final base = switch (color) {
    HighlightColor.yellow => palette.highlightYellow,
    HighlightColor.green => palette.highlightGreen,
    HighlightColor.blue => palette.highlightBlue,
    HighlightColor.pink => palette.highlightPink,
    HighlightColor.purple => palette.highlightPurple,
  };
  return base.withValues(alpha: _tintAlpha);
}

String practiceHighlightColorLabel(
  ReadflexLocalizations l10n,
  HighlightColor color,
) => switch (color) {
  HighlightColor.yellow => l10n.highlightColorYellow,
  HighlightColor.green => l10n.highlightColorGreen,
  HighlightColor.blue => l10n.highlightColorBlue,
  HighlightColor.pink => l10n.highlightColorPink,
  HighlightColor.purple => l10n.highlightColorPurple,
};
