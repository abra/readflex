import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_system_ui_overlay.dart';

void main() {
  group('readerSystemUiOverlayStyle', () {
    test('uses dark system icons for light reader themes', () {
      final theme = ReaderThemePreset.paper.data;
      const appNavigationBarColor = Color(0xFFF5F5F5);
      final style = readerSystemUiOverlayStyle(
        readerTheme: theme,
        chromeVisible: false,
        chromeSurfaceColor: Colors.black,
        appNavigationBarColor: appNavigationBarColor,
      );

      expect(style.statusBarColor, Colors.transparent);
      expect(style.statusBarIconBrightness, Brightness.dark);
      expect(style.statusBarBrightness, Brightness.light);
      expect(style.systemNavigationBarColor, appNavigationBarColor);
      expect(style.systemNavigationBarIconBrightness, Brightness.dark);
      expect(style.systemStatusBarContrastEnforced, isFalse);
      expect(style.systemNavigationBarContrastEnforced, isFalse);
    });

    test('uses light system icons for dark reader themes', () {
      final theme = ReaderThemePreset.night.data;
      const appNavigationBarColor = Color(0xFF111111);
      final style = readerSystemUiOverlayStyle(
        readerTheme: theme,
        chromeVisible: false,
        chromeSurfaceColor: Colors.white,
        appNavigationBarColor: appNavigationBarColor,
      );

      expect(style.statusBarColor, Colors.transparent);
      expect(style.statusBarIconBrightness, Brightness.light);
      expect(style.statusBarBrightness, Brightness.dark);
      expect(style.systemNavigationBarColor, appNavigationBarColor);
      expect(style.systemNavigationBarIconBrightness, Brightness.light);
      expect(style.systemStatusBarContrastEnforced, isFalse);
      expect(style.systemNavigationBarContrastEnforced, isFalse);
    });

    test('uses chrome surface while reader chrome is visible', () {
      final theme = ReaderThemePreset.paper.data;
      const chromeSurfaceColor = Color(0xFF111111);
      const appNavigationBarColor = Color(0xFFF5F5F5);
      final style = readerSystemUiOverlayStyle(
        readerTheme: theme,
        chromeVisible: true,
        chromeSurfaceColor: chromeSurfaceColor,
        appNavigationBarColor: appNavigationBarColor,
      );

      expect(style.statusBarIconBrightness, Brightness.light);
      expect(style.statusBarBrightness, Brightness.dark);
      expect(style.systemNavigationBarColor, appNavigationBarColor);
      expect(style.systemNavigationBarIconBrightness, Brightness.dark);
    });
  });
}
