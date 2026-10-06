import 'package:component_library/component_library.dart';
import 'package:flutter/services.dart';

/// Status icons follow whatever surface sits under the status bar: the app
/// chrome while the toolbar or a full-height panel (Contents, Search) is
/// shown, otherwise the reader page. The appearance sheet only scrims the
/// page, so it keeps the page-derived brightness.
SystemUiOverlayStyle readerSystemUiOverlayStyle({
  required ReaderThemeData readerTheme,
  required bool chromeVisible,
  required Color chromeSurfaceColor,
  required Color appNavigationBarColor,
  bool panelVisible = false,
}) {
  final statusSurfaceColor = chromeVisible || panelVisible
      ? chromeSurfaceColor
      : readerTheme.backgroundColor;
  final statusBrightness = _surfaceBrightness(statusSurfaceColor);
  final navigationBrightness = _surfaceBrightness(appNavigationBarColor);

  return appSystemUiOverlayStyle(
    brightness: statusBrightness,
    backgroundColor: statusSurfaceColor,
    navigationBarColor: appNavigationBarColor,
  ).copyWith(
    systemNavigationBarIconBrightness: _iconBrightnessFor(
      navigationBrightness,
    ),
  );
}

Brightness _surfaceBrightness(Color color) =>
    color.computeLuminance() < 0.5 ? Brightness.dark : Brightness.light;

Brightness _iconBrightnessFor(Brightness surfaceBrightness) =>
    surfaceBrightness == Brightness.dark ? Brightness.light : Brightness.dark;
