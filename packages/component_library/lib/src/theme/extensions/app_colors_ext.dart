import 'package:flutter/material.dart';

/// Semantic color tokens that extend [ThemeData] beyond [ColorScheme].
///
/// Access via `Theme.of(context).extension<AppColorsExt>()!`
/// or the shorthand `Theme.of(context).ext`.
class AppColorsExt extends ThemeExtension<AppColorsExt> {
  const AppColorsExt({
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
    required this.success,
    required this.successForeground,
    required this.proBadge,
    required this.proBadgeForeground,
    required this.divider,
  });

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
  final Color success;
  final Color successForeground;
  final Color proBadge;
  final Color proBadgeForeground;
  final Color divider;

  @override
  ThemeExtension<AppColorsExt> copyWith({
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
    Color? success,
    Color? successForeground,
    Color? proBadge,
    Color? proBadgeForeground,
    Color? divider,
  }) {
    return AppColorsExt(
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
      success: success ?? this.success,
      successForeground: successForeground ?? this.successForeground,
      proBadge: proBadge ?? this.proBadge,
      proBadgeForeground: proBadgeForeground ?? this.proBadgeForeground,
      divider: divider ?? this.divider,
    );
  }

  @override
  ThemeExtension<AppColorsExt> lerp(
    covariant ThemeExtension<AppColorsExt>? other,
    double t,
  ) {
    if (other is! AppColorsExt) return this;
    return AppColorsExt(
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
      divider: Color.lerp(divider, other.divider, t)!,
    );
  }
}

/// Convenience accessor for [AppColorsExt] on [ThemeData].
extension AppColorsExtX on ThemeData {
  AppColorsExt get ext => extension<AppColorsExt>()!;
}
