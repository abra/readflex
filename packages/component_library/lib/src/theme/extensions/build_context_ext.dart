import 'package:flutter/material.dart';

import 'app_colors_ext.dart';
import 'app_dimens_ext.dart';

/// Convenience accessors on [BuildContext] for cleaner UI code.
///
/// ```dart
/// Text('Hello', style: context.text.bodyLarge);
/// Icon(Icons.star, color: context.colors.primary);
/// Container(color: context.appColors.warning);
/// Padding(padding: EdgeInsets.all(context.dimens.spacingLg));
/// ```
extension BuildContextThemeX on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => theme.colorScheme;
  TextTheme get text => theme.textTheme;
  AppColorsExt get appColors => theme.ext;
  AppDimensExt get dimens => theme.extension<AppDimensExt>()!;
}
