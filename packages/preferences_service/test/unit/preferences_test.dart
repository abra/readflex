import 'dart:ui' show Locale;

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:preferences_service/preferences_service.dart';

const _baseRA = ReaderAppearancePreferences(
  themeId: 'paper',
  fontId: 'serif',
  layoutId: 'standard',
  textScale: 1.0,
  lineHeight: 1.55,
  invertImagesInDark: true,
  overrideFont: true,
  overrideColor: true,
  useBookLayout: true,
);

void main() {
  group('Preferences', () {
    test('defaults', () {
      const prefs = Preferences();
      expect(prefs.themeMode, ThemeMode.system);
      expect(prefs.locale, const Locale('en'));
      expect(prefs.catalogLayoutMode, 'grid');
      expect(prefs.readerThemeId, 'paper');
      expect(prefs.readerFontId, 'serif');
      expect(prefs.readerLayoutId, 'standard');
      expect(prefs.readerTextScale, 1.0);
      expect(prefs.readerLineHeight, 1.55);
      expect(prefs.readerInvertImagesInDark, isTrue);
      expect(prefs.readerOverrideFont, isTrue);
      expect(prefs.readerOverrideColor, isTrue);
      expect(prefs.readerUseBookLayout, isTrue);
      expect(prefs.readerSearchHistory, isEmpty);
      expect(prefs.onboardingCompleted, isFalse);
      expect(prefs.hasCompletedSetup, isFalse);
    });

    test('copyWith updates selected fields', () {
      const prefs = Preferences();
      final updated = prefs.copyWith(
        themeMode: ThemeMode.dark,
        locale: const Locale('ru'),
        catalogLayoutMode: 'list',
        readerSearchHistory: const ['design patterns', 'bloc'],
        onboardingCompleted: true,
      );

      expect(updated.themeMode, ThemeMode.dark);
      expect(updated.locale, const Locale('ru'));
      expect(updated.catalogLayoutMode, 'list');
      expect(updated.readerSearchHistory, ['design patterns', 'bloc']);
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

    test('equality compares readerSearchHistory by value', () {
      const a = Preferences(readerSearchHistory: ['flutter', 'bloc']);
      const b = Preferences(readerSearchHistory: ['flutter', 'bloc']);
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
        readerOverrideFont: false,
        readerOverrideColor: false,
        readerUseBookLayout: false,
      );
      final ra = prefs.readerAppearance;

      expect(ra.themeId, 'night');
      expect(ra.fontId, 'geist');
      expect(ra.layoutId, 'comfortable');
      expect(ra.textScale, 1.2);
      expect(ra.lineHeight, 1.8);
      expect(ra.invertImagesInDark, isFalse);
      expect(ra.overrideFont, isFalse);
      expect(ra.overrideColor, isFalse);
      expect(ra.useBookLayout, isFalse);
    });
  });

  group('ReaderAppearancePreferences', () {
    test('copyWith updates selected fields', () {
      final updated = _baseRA.copyWith(
        themeId: 'night',
        textScale: 1.3,
        layoutId: 'compact',
        invertImagesInDark: false,
        overrideFont: false,
      );

      expect(updated.themeId, 'night');
      expect(updated.fontId, 'serif');
      expect(updated.layoutId, 'compact');
      expect(updated.textScale, 1.3);
      expect(updated.lineHeight, 1.55);
      expect(updated.invertImagesInDark, isFalse);
      expect(updated.overrideFont, isFalse);
      expect(updated.overrideColor, isTrue);
      expect(updated.useBookLayout, isTrue);
    });

    test('equality', () {
      const a = _baseRA;
      const b = ReaderAppearancePreferences(
        themeId: 'paper',
        fontId: 'serif',
        layoutId: 'standard',
        textScale: 1.0,
        lineHeight: 1.55,
        invertImagesInDark: true,
        overrideFont: true,
        overrideColor: true,
        useBookLayout: true,
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('different fields are not equal', () {
      expect(_baseRA, isNot(equals(_baseRA.copyWith(fontId: 'geist'))));
      expect(
        _baseRA,
        isNot(equals(_baseRA.copyWith(layoutId: 'comfortable'))),
      );
      expect(
        _baseRA,
        isNot(equals(_baseRA.copyWith(invertImagesInDark: false))),
      );
      expect(_baseRA, isNot(equals(_baseRA.copyWith(overrideFont: false))));
      expect(_baseRA, isNot(equals(_baseRA.copyWith(overrideColor: false))));
      expect(_baseRA, isNot(equals(_baseRA.copyWith(useBookLayout: false))));
    });
  });
}
