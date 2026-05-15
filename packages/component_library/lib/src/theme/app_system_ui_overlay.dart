import 'package:flutter/material.dart';
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
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: iconBrightness,
    statusBarBrightness: brightness,
    systemNavigationBarColor: navigationBarColor ?? backgroundColor,
    systemNavigationBarIconBrightness: iconBrightness,
    systemNavigationBarDividerColor: Colors.transparent,
    systemStatusBarContrastEnforced: false,
    systemNavigationBarContrastEnforced: false,
  );
}
