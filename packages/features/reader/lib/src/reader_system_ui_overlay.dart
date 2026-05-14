import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

SystemUiOverlayStyle readerSystemUiOverlayStyle(ReaderThemeData theme) {
  final isDark = theme.backgroundColor.computeLuminance() < 0.5;
  final iconBrightness = isDark ? Brightness.light : Brightness.dark;

  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: iconBrightness,
    statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
    systemNavigationBarColor: theme.backgroundColor,
    systemNavigationBarIconBrightness: iconBrightness,
    systemNavigationBarDividerColor: Colors.transparent,
    systemStatusBarContrastEnforced: false,
    systemNavigationBarContrastEnforced: false,
  );
}
