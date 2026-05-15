import 'package:component_library/component_library.dart';
import 'package:flutter/services.dart';

SystemUiOverlayStyle readerSystemUiOverlayStyle({
  required ReaderThemeData readerTheme,
  required bool chromeVisible,
  required Color chromeSurfaceColor,
}) {
  final surfaceColor = chromeVisible
      ? chromeSurfaceColor
      : readerTheme.backgroundColor;
  final brightness = surfaceColor.computeLuminance() < 0.5
      ? Brightness.dark
      : Brightness.light;

  return appSystemUiOverlayStyle(
    brightness: brightness,
    backgroundColor: surfaceColor,
  );
}
