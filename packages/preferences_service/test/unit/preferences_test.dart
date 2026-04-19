import 'dart:ui' show Locale;

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:preferences_service/preferences_service.dart';

void main() {
  group('Preferences', () {
    test('defaults', () {
      const prefs = Preferences();
      expect(prefs.themeMode, ThemeMode.system);
      expect(prefs.locale, const Locale('en'));
      expect(prefs.contentLibraryLayoutMode, 'grid');
      expect(prefs.readerThemeId, 'paper');
      expect(prefs.readerFontId, 'serif');
      expect(prefs.readerLayoutId, 'standard');
      expect(prefs.readerTextScale, 1.0);
      expect(prefs.readerLineHeight, 1.55);
      expect(prefs.readerInvertImagesInDark, isTrue);
      expect(prefs.onboardingCompleted, isFalse);
      expect(prefs.hasCompletedSetup, isFalse);
    });

    test('copyWith updates selected fields', () {
      const prefs = Preferences();
      final updated = prefs.copyWith(
        themeMode: ThemeMode.dark,
        locale: const Locale('ru'),
        contentLibraryLayoutMode: 'list',
        onboardingCompleted: true,
      );

      expect(updated.themeMode, ThemeMode.dark);
      expect(updated.locale, const Locale('ru'));
      expect(updated.contentLibraryLayoutMode, 'list');
      expect(updated.onboardingCompleted, isTrue);
      // Unchanged fields preserved
      expect(updated.readerThemeId, 'paper');
      expect(updated.readerFontId, 'serif');
    });

    test('equality', () {
      const a = Preferences();
      const b = Preferences();
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('different fields are not equal', () {
      const a = Preferences();
      final b = a.copyWith(themeMode: ThemeMode.dark);
      expect(a, isNot(equals(b)));
    });

    test('readerAppearance getter builds from fields', () {
      const prefs = Preferences(
        readerThemeId: 'night',
        readerFontId: 'geist',
        readerLayoutId: 'comfortable',
        readerTextScale: 1.2,
        readerLineHeight: 1.8,
        readerInvertImagesInDark: false,
      );
      final ra = prefs.readerAppearance;

      expect(ra.themeId, 'night');
      expect(ra.fontId, 'geist');
      expect(ra.layoutId, 'comfortable');
      expect(ra.textScale, 1.2);
      expect(ra.lineHeight, 1.8);
      expect(ra.invertImagesInDark, isFalse);
    });
  });

  group('ReaderAppearancePreferences', () {
    test('copyWith updates selected fields', () {
      const ra = ReaderAppearancePreferences(
        themeId: 'paper',
        fontId: 'serif',
        layoutId: 'standard',
        textScale: 1.0,
        lineHeight: 1.55,
        invertImagesInDark: true,
      );
      final updated = ra.copyWith(
        themeId: 'night',
        textScale: 1.3,
        layoutId: 'compact',
        invertImagesInDark: false,
      );

      expect(updated.themeId, 'night');
      expect(updated.fontId, 'serif');
      expect(updated.layoutId, 'compact');
      expect(updated.textScale, 1.3);
      expect(updated.lineHeight, 1.55);
      expect(updated.invertImagesInDark, isFalse);
    });

    test('equality', () {
      const a = ReaderAppearancePreferences(
        themeId: 'paper',
        fontId: 'serif',
        layoutId: 'standard',
        textScale: 1.0,
        lineHeight: 1.55,
        invertImagesInDark: true,
      );
      const b = ReaderAppearancePreferences(
        themeId: 'paper',
        fontId: 'serif',
        layoutId: 'standard',
        textScale: 1.0,
        lineHeight: 1.55,
        invertImagesInDark: true,
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('different fields are not equal', () {
      const a = ReaderAppearancePreferences(
        themeId: 'paper',
        fontId: 'serif',
        layoutId: 'standard',
        textScale: 1.0,
        lineHeight: 1.55,
        invertImagesInDark: true,
      );
      final b = a.copyWith(fontId: 'geist');
      expect(a, isNot(equals(b)));
      final c = a.copyWith(layoutId: 'comfortable');
      expect(a, isNot(equals(c)));
      final d = a.copyWith(invertImagesInDark: false);
      expect(a, isNot(equals(d)));
    });
  });
}
