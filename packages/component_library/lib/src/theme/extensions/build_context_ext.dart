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
}
