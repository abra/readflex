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

    // The top chrome is a line on the page and every reader sheet stops below
    // the status bar, so the status icons only ever follow the page.
    for (final preset in ReaderThemePreset.values) {
      test('status icons follow the ${preset.id} page', () {
        final theme = preset.data;
        final pageIsDark = theme.backgroundColor.computeLuminance() < 0.5;
        for (final navigationBar in [Colors.white, Colors.black]) {
          final style = readerSystemUiOverlayStyle(
            readerTheme: theme,
            appNavigationBarColor: navigationBar,
          );
          expect(
            style.statusBarIconBrightness,
            pageIsDark ? Brightness.light : Brightness.dark,
          );
        }
      });
    }

    test('navigation icons follow the app navigation bar, not the page', () {
      final style = readerSystemUiOverlayStyle(
        readerTheme: ReaderThemePreset.night.data,
        appNavigationBarColor: Colors.white,
      );

      expect(style.statusBarIconBrightness, Brightness.light);
      expect(style.systemNavigationBarIconBrightness, Brightness.dark);
    });
  });
}
