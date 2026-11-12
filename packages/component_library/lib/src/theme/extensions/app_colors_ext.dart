import 'package:material_ui/material_ui.dart';

import '../app_theme_data.dart';

/// Semantic color tokens that extend [ThemeData] beyond [ColorScheme].
///
/// Access via `Theme.of(context).extension<AppColorsExt>()!`
/// or the shorthand `Theme.of(context).ext`.
class AppColorsExt extends ThemeExtension<AppColorsExt>
    implements AppStatusColors {
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
    required this.successContainer,
    required this.onSuccessContainer,
    required this.successOnInverse,
    required this.errorOnInverse,
    required this.proBadge,
    required this.proBadgeForeground,
    required this.divider,
    required this.onLightSwatch,
    required this.onDarkSwatch,
  });

  @override
  final Color highlightYellow;
  @override
  final Color highlightBlue;
  @override
  final Color highlightGreen;
  @override
  final Color highlightPink;
  @override
  final Color highlightPurple;
  @override
  final Color ratingAgain;
  @override
  final Color ratingHard;
  @override
  final Color ratingGood;
  @override
  final Color ratingEasy;
  @override
  final Color warning;
  @override
  final Color warningForeground;
  @override
  final Color info;
  @override
  final Color success;
  @override
  final Color successForeground;
  @override
  final Color successContainer;
  @override
  final Color onSuccessContainer;

  /// Status glyphs on [ColorScheme.inverseSurface], the neutral plate of a
  /// notification: the other theme's success and error tones, so they read
  /// on the inverted background.
  @override
  final Color successOnInverse;
  @override
  final Color errorOnInverse;
  @override
  final Color proBadge;
  @override
  final Color proBadgeForeground;
  @override
  final Color divider;

  /// Ink for a check or glyph drawn over a light sample color (a highlight
  /// swatch, a reader theme preview); [onDarkSwatch] is its counterpart.
  @override
  final Color onLightSwatch;
  @override
  final Color onDarkSwatch;

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
    Color? successContainer,
    Color? onSuccessContainer,
    Color? successOnInverse,
    Color? errorOnInverse,
    Color? proBadge,
    Color? proBadgeForeground,
    Color? divider,
    Color? onLightSwatch,
    Color? onDarkSwatch,
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
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      successOnInverse: successOnInverse ?? this.successOnInverse,
      errorOnInverse: errorOnInverse ?? this.errorOnInverse,
      proBadge: proBadge ?? this.proBadge,
      proBadgeForeground: proBadgeForeground ?? this.proBadgeForeground,
      divider: divider ?? this.divider,
      onLightSwatch: onLightSwatch ?? this.onLightSwatch,
      onDarkSwatch: onDarkSwatch ?? this.onDarkSwatch,
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
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      onSuccessContainer: Color.lerp(
        onSuccessContainer,
        other.onSuccessContainer,
        t,
      )!,
      successOnInverse: Color.lerp(
        successOnInverse,
        other.successOnInverse,
        t,
      )!,
      errorOnInverse: Color.lerp(errorOnInverse, other.errorOnInverse, t)!,
      proBadge: Color.lerp(proBadge, other.proBadge, t)!,
      proBadgeForeground: Color.lerp(
        proBadgeForeground,
        other.proBadgeForeground,
        t,
      )!,
      divider: Color.lerp(divider, other.divider, t)!,
      onLightSwatch: Color.lerp(onLightSwatch, other.onLightSwatch, t)!,
      onDarkSwatch: Color.lerp(onDarkSwatch, other.onDarkSwatch, t)!,
    );
  }
}

/// Convenience accessor for [AppColorsExt] on [ThemeData].
extension AppColorsExtX on ThemeData {
  AppColorsExt get ext => extension<AppColorsExt>()!;
}
