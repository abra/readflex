import 'package:component_library/component_library.dart';
import 'package:flutter/services.dart';

SystemUiOverlayStyle readerSystemUiOverlayStyle({
  required ReaderThemeData readerTheme,
  required bool chromeVisible,
  required Color chromeSurfaceColor,
  required Color appNavigationBarColor,
}) {
  final statusSurfaceColor = chromeVisible
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
