import 'package:flutter/services.dart';

SystemUiOverlayStyle appSystemUiOverlayStyle({
  required Brightness brightness,
  required Color backgroundColor,
  Color? navigationBarColor,
}) {
  final iconBrightness = brightness == Brightness.dark
      ? Brightness.light
      : Brightness.dark;

  return SystemUiOverlayStyle(
    statusBarColor: const Color(0x00000000),
    statusBarIconBrightness: iconBrightness,
    statusBarBrightness: brightness,
    systemNavigationBarColor: navigationBarColor ?? backgroundColor,
    systemNavigationBarIconBrightness: iconBrightness,
    systemNavigationBarDividerColor: const Color(0x00000000),
    systemStatusBarContrastEnforced: false,
    systemNavigationBarContrastEnforced: false,
  );
}
