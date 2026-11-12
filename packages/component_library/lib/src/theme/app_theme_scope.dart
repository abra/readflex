import 'package:flutter/widgets.dart';

import 'app_theme_data.dart';

/// Captured by routes and sheets together with platform themes.
class AppThemeScope extends InheritedTheme {
  const AppThemeScope({required this.data, required super.child, super.key});

  final AppThemeData data;

  static AppThemeData? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppThemeScope>()?.data;

  @override
  bool updateShouldNotify(AppThemeScope oldWidget) =>
      !identical(data, oldWidget.data);

  @override
  Widget wrap(BuildContext context, Widget child) =>
      AppThemeScope(data: data, child: child);
}
