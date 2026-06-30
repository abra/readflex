import 'dart:ui' show Locale;

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:preferences_service/preferences_service.dart';

const _baseRA = ReaderAppearancePreferences(
  themeId: 'paper',
  fontId: 'serif',
  layoutId: 'standard',
  textScale: 1.0,
  lineHeight: 1.6,
  sideMargin: 8.0,
  textAlignment: ReaderTextAlignment.start,
  invertImagesInDark: false,
  overrideFont: true,
  overrideColor: true,
  useBookLayout: true,
  pageTurnStyle: ReaderPageTurnStyle.horizontal,
);

void main() {
  group('Preferences', () {
    test('defaults', () {
      const prefs = Preferences();
      expect(prefs.themeMode, ThemeMode.system);
      expect(prefs.locale, const Locale('en'));
      expect(prefs.libraryLayoutMode, 'grid');
      expect(prefs.readerThemeId, 'paper');
      expect(prefs.readerFontId, 'serif');
      expect(prefs.readerLayoutId, 'standard');
      expect(prefs.readerTextScale, 1.0);
      expect(prefs.readerLineHeight, 1.6);
      expect(prefs.readerSideMargin, 8.0);
      expect(prefs.readerTextAlignment, ReaderTextAlignment.start);
      expect(prefs.readerInvertImagesInDark, isFalse);
      expect(prefs.readerOverrideFont, isTrue);
      expect(prefs.readerOverrideColor, isTrue);
      expect(prefs.readerUseBookLayout, isTrue);
      expect(prefs.readerPageTurnStyle, ReaderPageTurnStyle.horizontal);
      expect(prefs.readerSearchHistory, isEmpty);
      expect(prefs.readerBrightness, isNull);
      expect(prefs.readerLastCustomBrightness, 0.7);
      expect(prefs.readerAppearanceOverrides, isEmpty);
      expect(prefs.onboardingCompleted, isFalse);
    });

    test('copyWith updates selected fields', () {
      const prefs = Preferences();
      final updated = prefs.copyWith(
        themeMode: ThemeMode.dark,
        locale: const Locale('ru'),
        libraryLayoutMode: 'list',
        readerPageTurnStyle: ReaderPageTurnStyle.vertical,
        readerSearchHistory: const ['design patterns', 'bloc'],
        readerBrightness: 0.55,
        readerLastCustomBrightness: 0.8,
        readerAppearanceOverrides: const {
          'source-1': ReaderAppearanceOverride(
            fontId: 'sans',
            brightnessOverride: 0.42,
          ),
        },
        onboardingCompleted: true,
      );

      expect(updated.themeMode, ThemeMode.dark);
      expect(updated.locale, const Locale('ru'));
      expect(updated.libraryLayoutMode, 'list');
      expect(updated.readerPageTurnStyle, ReaderPageTurnStyle.vertical);
      expect(updated.readerSearchHistory, ['design patterns', 'bloc']);
      expect(updated.readerBrightness, 0.55);
      expect(updated.readerLastCustomBrightness, 0.8);
      expect(updated.readerAppearanceOverrides['source-1']?.fontId, 'sans');
      expect(updated.readerBrightnessOverrideFor('source-1'), 0.42);
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

    test('copyWith can clear reader brightness', () {
      const prefs = Preferences(readerBrightness: 0.55);
      final updated = prefs.copyWith(readerBrightness: null);

      expect(updated.readerBrightness, isNull);
      expect(updated.readerLastCustomBrightness, 0.7);
    });

    test('equality compares readerAppearanceOverrides by value', () {
      const a = Preferences(
        readerAppearanceOverrides: {
          'source-1': ReaderAppearanceOverride(fontId: 'sans'),
        },
      );
      const b = Preferences(
        readerAppearanceOverrides: {
          'source-1': ReaderAppearanceOverride(fontId: 'sans'),
        },
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('different fields are not equal', () {
      const a = Preferences();
      final b = a.copyWith(themeMode: ThemeMode.dark);
      expect(a, isNot(equals(b)));
      expect(a, isNot(equals(a.copyWith(readerBrightness: 0.55))));
      expect(
        a,
        isNot(equals(a.copyWith(readerLastCustomBrightness: 0.55))),
      );
    });

    test('readerBrightnessOverrideFor reads source-specific override', () {
      const prefs = Preferences(
        readerAppearanceOverrides: {
          'source-1': ReaderAppearanceOverride(brightnessOverride: 0.4),
        },
      );

      expect(prefs.readerBrightnessOverrideFor('source-1'), 0.4);
      expect(prefs.readerBrightnessOverrideFor('source-2'), isNull);
    });

    test('readerAppearance getter builds from fields', () {
      const prefs = Preferences(
        readerThemeId: 'night',
        readerFontId: 'geist',
        readerLayoutId: 'comfortable',
        readerTextScale: 1.2,
        readerLineHeight: 1.8,
        readerSideMargin: 9,
        readerTextAlignment: ReaderTextAlignment.justify,
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
      expect(ra.sideMargin, 9);
      expect(ra.textAlignment, ReaderTextAlignment.justify);
      expect(ra.invertImagesInDark, isFalse);
      expect(ra.overrideFont, isFalse);
      expect(ra.overrideColor, isFalse);
      expect(ra.useBookLayout, isFalse);
    });

    test('effectiveReaderAppearanceFor applies source override', () {
      const prefs = Preferences(
        readerFontId: 'serif',
        readerTextScale: 1.0,
        readerLineHeight: 1.6,
        readerAppearanceOverrides: {
          'source-1': ReaderAppearanceOverride(
            fontId: 'sans',
            textScale: 1.2,
            sideMargin: 10,
            textAlignment: ReaderTextAlignment.justify,
          ),
        },
      );

      final ra = prefs.effectiveReaderAppearanceFor('source-1');

      expect(ra.fontId, 'sans');
      expect(ra.textScale, 1.2);
      expect(ra.lineHeight, 1.6);
      expect(ra.sideMargin, 10);
      expect(ra.textAlignment, ReaderTextAlignment.justify);
      expect(
        prefs.effectiveReaderAppearanceFor('source-2'),
        prefs.readerAppearance,
      );
    });
  });

  group('ReaderAppearancePreferences', () {
    test('copyWith updates selected fields', () {
      final updated = _baseRA.copyWith(
        themeId: 'night',
        textScale: 1.3,
        layoutId: 'compact',
        sideMargin: 8,
        textAlignment: ReaderTextAlignment.justify,
        invertImagesInDark: false,
        overrideFont: false,
        pageTurnStyle: ReaderPageTurnStyle.vertical,
      );

      expect(updated.themeId, 'night');
      expect(updated.fontId, 'serif');
      expect(updated.layoutId, 'compact');
      expect(updated.textScale, 1.3);
      expect(updated.lineHeight, 1.6);
      expect(updated.sideMargin, 8);
      expect(updated.textAlignment, ReaderTextAlignment.justify);
      expect(updated.invertImagesInDark, isFalse);
      expect(updated.overrideFont, isFalse);
      expect(updated.overrideColor, isTrue);
      expect(updated.useBookLayout, isTrue);
      expect(updated.pageTurnStyle, ReaderPageTurnStyle.vertical);
    });

    test('equality', () {
      const a = _baseRA;
      const b = ReaderAppearancePreferences(
        themeId: 'paper',
        fontId: 'serif',
        layoutId: 'standard',
        textScale: 1.0,
        lineHeight: 1.6,
        sideMargin: 8.0,
        textAlignment: ReaderTextAlignment.start,
        invertImagesInDark: false,
        overrideFont: true,
        overrideColor: true,
        useBookLayout: true,
        pageTurnStyle: ReaderPageTurnStyle.horizontal,
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
        isNot(equals(_baseRA.copyWith(invertImagesInDark: true))),
      );
      expect(_baseRA, isNot(equals(_baseRA.copyWith(sideMargin: 10))));
      expect(
        _baseRA,
        isNot(
          equals(
            _baseRA.copyWith(textAlignment: ReaderTextAlignment.justify),
          ),
        ),
      );
      expect(_baseRA, isNot(equals(_baseRA.copyWith(overrideFont: false))));
      expect(_baseRA, isNot(equals(_baseRA.copyWith(overrideColor: false))));
      expect(_baseRA, isNot(equals(_baseRA.copyWith(useBookLayout: false))));
      expect(
        _baseRA,
        isNot(
          equals(_baseRA.copyWith(pageTurnStyle: ReaderPageTurnStyle.vertical)),
        ),
      );
    });

    test('ReaderTextAlignment parses start end and justify IDs', () {
      expect(ReaderTextAlignment.fromId('start'), ReaderTextAlignment.start);
      expect(ReaderTextAlignment.fromId('end'), ReaderTextAlignment.end);
      expect(
        ReaderTextAlignment.fromId('justify'),
        ReaderTextAlignment.justify,
      );
      expect(ReaderTextAlignment.fromId('unknown'), ReaderTextAlignment.start);
      expect(ReaderTextAlignment.tryFromId('unknown'), isNull);
    });
  });

  group('ReaderAppearanceOverride', () {
    test('copyWith can set and clear nullable fields', () {
      const source = ReaderAppearanceOverride(fontId: 'sans');

      final updated = source.copyWith(
        fontId: null,
        textScale: 1.2,
        sideMargin: 8,
        textAlignment: ReaderTextAlignment.justify,
        brightnessOverride: 0.5,
      );

      expect(updated.fontId, isNull);
      expect(updated.textScale, 1.2);
      expect(updated.sideMargin, 8);
      expect(updated.textAlignment, ReaderTextAlignment.justify);
      expect(updated.brightnessOverride, 0.5);
    });

    test('toJson/fromJson round-trip omits null values', () {
      const source = ReaderAppearanceOverride(
        fontId: 'sans',
        textScale: 1.25,
        sideMargin: 9,
        textAlignment: ReaderTextAlignment.justify,
        overrideColor: false,
        brightnessOverride: 0.65,
      );

      final json = source.toJson();
      final loaded = ReaderAppearanceOverride.fromJson(json);

      expect(json.containsKey('themeId'), isFalse);
      expect(loaded, source);
    });
  });
}
