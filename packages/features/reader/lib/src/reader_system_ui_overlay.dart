import 'package:component_library/component_library.dart';
import 'package:flutter/services.dart';

/// Status icons follow the reader page under the status bar. The top chrome
/// is a line drawn on the page, and the Appearance, Contents and Search sheets
/// stop below the status bar and only scrim the page, so all of them keep the
/// page-derived brightness.
SystemUiOverlayStyle readerSystemUiOverlayStyle({
  required ReaderThemeData readerTheme,
  required Color appNavigationBarColor,
}) {
  final statusSurfaceColor = readerTheme.backgroundColor;
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
