import 'package:flutter/material.dart';

import '../app_text_theme.dart';
import 'app_colors_ext.dart';

/// Convenience accessors on [BuildContext] for cleaner UI code.
///
/// ```dart
/// Text('Hello', style: context.text.bodyLarge);
/// Icon(Icons.star, color: context.colors.primary);
/// Container(color: context.appColors.warning);
/// ```
///
/// [text] returns an [AppTextTheme] wrapper whose fields are non-null —
/// `AppTypography.textTheme` always defines every role, so call sites don't
/// need the `!` operator.
extension BuildContextThemeX on BuildContext {
  ThemeData get theme => Theme.of(this);

  ColorScheme get colors => theme.colorScheme;

  AppTextTheme get text => AppTextTheme(theme.textTheme);

  AppColorsExt get appColors => theme.ext;

  /// Accent on app surfaces, not the fill of primary buttons or reader pages.
  Color get actionForeground => colors.brightness == Brightness.dark
      ? colors.primaryFixedDim
      : colors.primary;

  /// True when the platform asks to reduce motion.
  bool get reduceMotion => MediaQuery.disableAnimationsOf(this);

  /// Resolves an [AppMotion] token for an implicit animation: the token as
  /// given, or [Duration.zero] under reduced motion so the widget settles in
  /// one frame instead of tweening.
  Duration motion(Duration duration) => reduceMotion ? Duration.zero : duration;
}
