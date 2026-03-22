import 'package:flutter/material.dart';

import 'app_theme_data.dart';

/// Provides [AppThemeData] to the widget tree.
///
/// Wrap [MaterialApp] with this widget and pass both light and dark themes.
/// Components read the current theme via [AppTheme.of]:
/// ```dart
/// final theme = AppTheme.of(context);
/// ```
///
/// The correct variant (light or dark) is selected automatically based on
/// [Theme.of(context).brightness].
class AppTheme extends InheritedWidget {
  const AppTheme({
    required this.lightTheme,
    required this.darkTheme,
    required super.child,
    super.key,
  });

  final AppThemeData lightTheme;
  final AppThemeData darkTheme;

  /// Returns the [AppThemeData] matching the current brightness.
  static AppThemeData of(BuildContext context) {
    final theme = context.dependOnInheritedWidgetOfExactType<AppTheme>();
    if (theme == null) {
      throw FlutterError(
        'AppTheme.of() called with a context that does not contain an AppTheme.\n'
        'Ensure the widget tree includes an AppTheme ancestor.',
      );
    }
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? theme.darkTheme : theme.lightTheme;
  }

  @override
  bool updateShouldNotify(AppTheme old) =>
      lightTheme != old.lightTheme || darkTheme != old.darkTheme;
}
