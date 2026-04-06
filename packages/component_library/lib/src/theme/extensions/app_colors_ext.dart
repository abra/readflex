import 'package:flutter/material.dart';

/// Semantic color tokens that extend [ThemeData] beyond [ColorScheme].
///
/// Access via `Theme.of(context).extension<AppColorsExt>()!`
/// or the shorthand `Theme.of(context).ext`.
class AppColorsExt extends ThemeExtension<AppColorsExt> {
  const AppColorsExt({
    required this.readingSurface,
    required this.readingText,
    required this.highlightYellow,
    required this.highlightBlue,
    required this.highlightGreen,
    required this.highlightPink,
    required this.highlightPurple,
    required this.ratingAgain,
    required this.ratingHard,
    required this.ratingGood,
    required this.ratingEasy,
    required this.warning,
    required this.warningForeground,
    required this.info,
    required this.infoForeground,
    required this.success,
    required this.successForeground,
    required this.proBadge,
    required this.proBadgeForeground,
    required this.tabActive,
    required this.tabInactive,
    required this.divider,
    required this.aiAccent,
  });

  final Color readingSurface;
  final Color readingText;
  final Color highlightYellow;
  final Color highlightBlue;
  final Color highlightGreen;
  final Color highlightPink;
  final Color highlightPurple;
  final Color ratingAgain;
  final Color ratingHard;
  final Color ratingGood;
  final Color ratingEasy;
  final Color warning;
  final Color warningForeground;
  final Color info;
  final Color infoForeground;
  final Color success;
  final Color successForeground;
  final Color proBadge;
  final Color proBadgeForeground;
  final Color tabActive;
  final Color tabInactive;
  final Color divider;
  final Color aiAccent;

  @override
  ThemeExtension<AppColorsExt> copyWith({
    Color? readingSurface,
    Color? readingText,
    Color? highlightYellow,
    Color? highlightBlue,
    Color? highlightGreen,
    Color? highlightPink,
    Color? highlightPurple,
    Color? ratingAgain,
    Color? ratingHard,
    Color? ratingGood,
    Color? ratingEasy,
    Color? warning,
    Color? warningForeground,
    Color? info,
    Color? infoForeground,
    Color? success,
    Color? successForeground,
    Color? proBadge,
    Color? proBadgeForeground,
    Color? tabActive,
    Color? tabInactive,
    Color? divider,
    Color? aiAccent,
  }) {
    return AppColorsExt(
      readingSurface: readingSurface ?? this.readingSurface,
      readingText: readingText ?? this.readingText,
      highlightYellow: highlightYellow ?? this.highlightYellow,
      highlightBlue: highlightBlue ?? this.highlightBlue,
      highlightGreen: highlightGreen ?? this.highlightGreen,
      highlightPink: highlightPink ?? this.highlightPink,
      highlightPurple: highlightPurple ?? this.highlightPurple,
      ratingAgain: ratingAgain ?? this.ratingAgain,
      ratingHard: ratingHard ?? this.ratingHard,
      ratingGood: ratingGood ?? this.ratingGood,
      ratingEasy: ratingEasy ?? this.ratingEasy,
      warning: warning ?? this.warning,
      warningForeground: warningForeground ?? this.warningForeground,
      info: info ?? this.info,
      infoForeground: infoForeground ?? this.infoForeground,
      success: success ?? this.success,
      successForeground: successForeground ?? this.successForeground,
      proBadge: proBadge ?? this.proBadge,
      proBadgeForeground: proBadgeForeground ?? this.proBadgeForeground,
      tabActive: tabActive ?? this.tabActive,
      tabInactive: tabInactive ?? this.tabInactive,
      divider: divider ?? this.divider,
      aiAccent: aiAccent ?? this.aiAccent,
    );
  }

  @override
  ThemeExtension<AppColorsExt> lerp(
    covariant ThemeExtension<AppColorsExt>? other,
    double t,
  ) {
    if (other is! AppColorsExt) return this;
    return AppColorsExt(
      readingSurface: Color.lerp(readingSurface, other.readingSurface, t)!,
      readingText: Color.lerp(readingText, other.readingText, t)!,
      highlightYellow: Color.lerp(highlightYellow, other.highlightYellow, t)!,
      highlightBlue: Color.lerp(highlightBlue, other.highlightBlue, t)!,
      highlightGreen: Color.lerp(highlightGreen, other.highlightGreen, t)!,
      highlightPink: Color.lerp(highlightPink, other.highlightPink, t)!,
      highlightPurple: Color.lerp(highlightPurple, other.highlightPurple, t)!,
      ratingAgain: Color.lerp(ratingAgain, other.ratingAgain, t)!,
      ratingHard: Color.lerp(ratingHard, other.ratingHard, t)!,
      ratingGood: Color.lerp(ratingGood, other.ratingGood, t)!,
      ratingEasy: Color.lerp(ratingEasy, other.ratingEasy, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningForeground: Color.lerp(
        warningForeground,
        other.warningForeground,
        t,
      )!,
      info: Color.lerp(info, other.info, t)!,
      infoForeground: Color.lerp(infoForeground, other.infoForeground, t)!,
      success: Color.lerp(success, other.success, t)!,
      successForeground: Color.lerp(
        successForeground,
        other.successForeground,
        t,
      )!,
      proBadge: Color.lerp(proBadge, other.proBadge, t)!,
      proBadgeForeground: Color.lerp(
        proBadgeForeground,
        other.proBadgeForeground,
        t,
      )!,
      tabActive: Color.lerp(tabActive, other.tabActive, t)!,
      tabInactive: Color.lerp(tabInactive, other.tabInactive, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      aiAccent: Color.lerp(aiAccent, other.aiAccent, t)!,
    );
  }
}

/// Convenience accessor for [AppColorsExt] on [ThemeData].
extension AppColorsExtX on ThemeData {
  AppColorsExt get ext => extension<AppColorsExt>()!;
}
