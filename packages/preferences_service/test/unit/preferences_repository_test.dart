import 'dart:convert' show jsonDecode, jsonEncode;
import 'dart:ui' show Locale;

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

const _supportedCodes = ['en', 'ru'];
const _key = 'app_preferences';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('PreferencesRepository', () {
    test('load() returns defaults when storage is empty', () async {
      final repo = PreferencesRepository(PreferencesStorage());
      final prefs = await repo.load(_supportedCodes);

      expect(prefs.themeMode, ThemeMode.system);
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

    test('load() reads legacy catalog layout preference', () async {
      final storage = PreferencesStorage();
      await storage.setString(
        _key,
        jsonEncode(<String, Object?>{
          'catalogLayoutMode': 'list',
        }),
      );

      final repo = PreferencesRepository(storage);
      final prefs = await repo.load(_supportedCodes);

      expect(prefs.libraryLayoutMode, 'list');
    });

    test('save() then load() round-trips all fields', () async {
      final repo = PreferencesRepository(PreferencesStorage());
      const source = Preferences(
        themeMode: ThemeMode.dark,
        locale: Locale('ru'),
        libraryLayoutMode: 'list',
        readerThemeId: 'night',
        readerFontId: 'geist',
        readerLayoutId: 'comfortable',
        readerTextScale: 1.3,
        readerLineHeight: 1.9,
        readerSideMargin: 10,
        readerTextAlignment: ReaderTextAlignment.justify,
        readerInvertImagesInDark: false,
        readerOverrideFont: false,
        readerOverrideColor: false,
        readerUseBookLayout: false,
        readerPageTurnStyle: ReaderPageTurnStyle.vertical,
        readerSearchHistory: ['design patterns', 'bloc'],
        readerBrightness: 0.65,
        readerLastCustomBrightness: 0.8,
        readerAppearanceOverrides: {
          'source-1': ReaderAppearanceOverride(
            themeId: 'night',
            fontId: 'sans',
            textScale: 1.2,
            lineHeight: 1.8,
            sideMargin: 9,
            textAlignment: ReaderTextAlignment.justify,
            pageTurnStyle: ReaderPageTurnStyle.horizontal,
            brightnessOverride: 0.42,
          ),
        },
        onboardingCompleted: true,
      );

      await repo.save(source);
      final loaded = await repo.load(_supportedCodes);

      expect(
        loaded,
        source.copyWith(
          readerAppearanceOverrides: const {
            'source-1': ReaderAppearanceOverride(
              fontId: 'sans',
              textScale: 1.2,
              lineHeight: 1.8,
              sideMargin: 9,
              pageTurnStyle: ReaderPageTurnStyle.horizontal,
              brightnessOverride: 0.42,
            ),
          },
        ),
      );
    });

    test('save() writes JSON with expected keys', () async {
      final storage = PreferencesStorage();
      final repo = PreferencesRepository(storage);
      const prefs = Preferences(
        readerLayoutId: 'compact',
        readerTextAlignment: ReaderTextAlignment.justify,
        readerInvertImagesInDark: false,
        readerOverrideFont: false,
        readerOverrideColor: false,
        readerUseBookLayout: false,
        readerPageTurnStyle: ReaderPageTurnStyle.vertical,
      );

      await repo.save(prefs);
      final raw = await storage.getString(_key);
      final map = jsonDecode(raw!) as Map<String, Object?>;

      expect(map['readerLayoutId'], 'compact');
      expect(map.containsKey('translationTargetLanguageCode'), isFalse);
      expect(map.containsKey('translationSourceLanguageCode'), isFalse);
      expect(map['readerTextAlignment'], 'justify');
      expect(map['readerInvertImagesInDark'], isFalse);
      expect(map['readerOverrideFont'], isFalse);
      expect(map['readerOverrideColor'], isFalse);
      expect(map['readerUseBookLayout'], isFalse);
      expect(map['readerPageTurnStyle'], 'vertical');
      expect(map.containsKey('readerBrightnessOverride'), isFalse);
      expect(map['readerBrightness'], isNull);
      expect(map['readerLastCustomBrightness'], 0.7);
      expect(map['readerSearchHistory'], isEmpty);
      expect(map['readerAppearanceOverrides'], isEmpty);
      expect(map['readerThemeId'], 'paper');
      expect(map['readerFontId'], 'serif');
      expect(map['readerTextScale'], 1.0);
      expect(map['readerLineHeight'], 1.6);
      expect(map['readerSideMargin'], 8.0);
    });

    test(
      'load() falls back to defaults for missing new fields in legacy JSON',
      () async {
        final storage = PreferencesStorage();
        await storage.setString(
          _key,
          jsonEncode(<String, Object?>{
            'themeMode': 'dark',
            'locale': 'en',
            'libraryLayoutMode': 'grid',
            'readerThemeId': 'paper',
            'readerFontId': 'serif',
            'readerTextScale': 1.0,
            'readerLineHeight': 1.6,
            'onboardingCompleted': true,
            // no readerLayoutId, no readerInvertImagesInDark
          }),
        );

        final repo = PreferencesRepository(storage);
        final prefs = await repo.load(_supportedCodes);

        expect(prefs.themeMode, ThemeMode.dark);
        expect(prefs.readerLayoutId, 'standard');
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
      },
    );

    test('load() ignores non-string readerSearchHistory entries', () async {
      final storage = PreferencesStorage();
      await storage.setString(
        _key,
        jsonEncode(<String, Object?>{
          '_schemaVersion': 2,
          'readerSearchHistory': ['flutter', 42, null, 'bloc'],
        }),
      );

      final repo = PreferencesRepository(storage);
      final prefs = await repo.load(_supportedCodes);

      expect(prefs.readerSearchHistory, ['flutter', 'bloc']);
    });

    test('load() clamps global reader brightness from JSON', () async {
      final storage = PreferencesStorage();
      await storage.setString(
        _key,
        jsonEncode(<String, Object?>{
          '_schemaVersion': 9,
          'readerBrightness': 2.0,
          'readerLastCustomBrightness': 0.0,
        }),
      );

      final repo = PreferencesRepository(storage);
      final prefs = await repo.load(_supportedCodes);

      expect(prefs.readerBrightness, 1.0);
      expect(prefs.readerLastCustomBrightness, 0.05);
    });

    test('load() clamps source reader brightness override from JSON', () async {
      final storage = PreferencesStorage();
      await storage.setString(
        _key,
        jsonEncode(<String, Object?>{
          '_schemaVersion': 7,
          'readerAppearanceOverrides': {
            'source-1': {'brightnessOverride': 2.0},
          },
        }),
      );

      final repo = PreferencesRepository(storage);
      final prefs = await repo.load(_supportedCodes);

      expect(prefs.readerBrightnessOverrideFor('source-1'), 1.0);
    });

    test('load() ignores invalid readerAppearanceOverrides entries', () async {
      final storage = PreferencesStorage();
      await storage.setString(
        _key,
        jsonEncode(<String, Object?>{
          '_schemaVersion': 3,
          'readerAppearanceOverrides': {
            'source-1': {
              'fontId': 'sans',
              'textScale': 1.25,
              'sideMargin': 9,
              'textAlignment': 'justify',
            },
            'empty': <String, Object?>{},
            'invalid': 'not a map',
            'source-2': {'textScale': 'large'},
          },
        }),
      );

      final repo = PreferencesRepository(storage);
      final prefs = await repo.load(_supportedCodes);

      expect(prefs.readerAppearanceOverrides.keys, ['source-1']);
      expect(prefs.readerAppearanceOverrides['source-1']?.fontId, 'sans');
      expect(prefs.readerAppearanceOverrides['source-1']?.textScale, 1.25);
      expect(prefs.readerAppearanceOverrides['source-1']?.sideMargin, 9);
      expect(
        prefs.readerAppearanceOverrides['source-1']?.textAlignment,
        ReaderTextAlignment.justify,
      );
    });

    test('load() falls back to defaults on corrupt JSON', () async {
      final storage = PreferencesStorage();
      await storage.setString(_key, 'not valid json');

      final repo = PreferencesRepository(storage);
      final prefs = await repo.load(_supportedCodes);

      expect(prefs, const Preferences());
    });

    test(
      'load() v1→v2 migration: forces readerFontId to serif when stored '
      'JSON has no _schemaVersion key',
      () async {
        final storage = PreferencesStorage();
        await storage.setString(
          _key,
          jsonEncode(<String, Object?>{
            // No _schemaVersion → treated as v1.
            'readerFontId': 'sans',
            'readerThemeId': 'paper',
          }),
        );

        final repo = PreferencesRepository(storage);
        final prefs = await repo.load(_supportedCodes);

        expect(prefs.readerFontId, 'serif');
      },
    );

    test(
      'load() leaves readerFontId alone when stored JSON already has '
      '_schemaVersion >= 2 (post-migration writes must not be reset)',
      () async {
        final storage = PreferencesStorage();
        await storage.setString(
          _key,
          jsonEncode(<String, Object?>{
            '_schemaVersion': 2,
            'readerFontId': 'geist',
          }),
        );

        final repo = PreferencesRepository(storage);
        final prefs = await repo.load(_supportedCodes);

        expect(prefs.readerFontId, 'geist');
      },
    );

    test(
      'load() v3→v4 migration resets global reader text scale to 100%',
      () async {
        final storage = PreferencesStorage();
        await storage.setString(
          _key,
          jsonEncode(<String, Object?>{
            '_schemaVersion': 3,
            'readerTextScale': 1.15,
          }),
        );

        final repo = PreferencesRepository(storage);
        final prefs = await repo.load(_supportedCodes);

        expect(prefs.readerTextScale, 1.0);
      },
    );

    test(
      'load() preserves readerTextScale when stored JSON is schema v4',
      () async {
        final storage = PreferencesStorage();
        await storage.setString(
          _key,
          jsonEncode(<String, Object?>{
            '_schemaVersion': 4,
            'readerTextScale': 1.15,
          }),
        );

        final repo = PreferencesRepository(storage);
        final prefs = await repo.load(_supportedCodes);

        expect(prefs.readerTextScale, 1.15);
      },
    );

    test(
      'load() v7→v8 migration raises old default reader side margin',
      () async {
        final storage = PreferencesStorage();
        await storage.setString(
          _key,
          jsonEncode(<String, Object?>{
            '_schemaVersion': 7,
            'readerSideMargin': 6.0,
          }),
        );

        final repo = PreferencesRepository(storage);
        final prefs = await repo.load(_supportedCodes);

        expect(prefs.readerSideMargin, 8.0);
      },
    );

    test(
      'load() v7→v8 migration preserves customized reader side margin',
      () async {
        final storage = PreferencesStorage();
        await storage.setString(
          _key,
          jsonEncode(<String, Object?>{
            '_schemaVersion': 7,
            'readerSideMargin': 10.0,
          }),
        );

        final repo = PreferencesRepository(storage);
        final prefs = await repo.load(_supportedCodes);

        expect(prefs.readerSideMargin, 10.0);
      },
    );

    test(
      'load() preserves schema v8 reader side margin values',
      () async {
        final storage = PreferencesStorage();
        await storage.setString(
          _key,
          jsonEncode(<String, Object?>{
            '_schemaVersion': 8,
            'readerSideMargin': 6.0,
          }),
        );

        final repo = PreferencesRepository(storage);
        final prefs = await repo.load(_supportedCodes);

        expect(prefs.readerSideMargin, 6.0);
      },
    );

    test(
      'load() v11→v12 migration resets global reader line height',
      () async {
        final storage = PreferencesStorage();
        await storage.setString(
          _key,
          jsonEncode(<String, Object?>{
            '_schemaVersion': 11,
            'readerLineHeight': 1.8,
          }),
        );

        final repo = PreferencesRepository(storage);
        final prefs = await repo.load(_supportedCodes);

        expect(prefs.readerLineHeight, 1.6);
      },
    );

    test(
      'load() drops source appearance overrides matching reader defaults',
      () async {
        final storage = PreferencesStorage();
        await storage.setString(
          _key,
          jsonEncode(<String, Object?>{
            '_schemaVersion': 11,
            'readerAppearanceOverrides': {
              'source-1': {'lineHeight': 1.6, 'fontId': 'sans'},
              'source-2': {'lineHeight': 1.6},
            },
          }),
        );

        final repo = PreferencesRepository(storage);
        final prefs = await repo.load(_supportedCodes);

        expect(prefs.readerAppearanceOverrideFor('source-1')?.fontId, 'sans');
        expect(
          prefs.readerAppearanceOverrideFor('source-1')?.lineHeight,
          isNull,
        );
        expect(prefs.readerAppearanceOverrideFor('source-2'), isNull);
      },
    );

    test('save() writes _schemaVersion key alongside the data', () async {
      final storage = PreferencesStorage();
      final repo = PreferencesRepository(storage);

      await repo.save(const Preferences());
      final raw = await storage.getString(_key);
      final map = jsonDecode(raw!) as Map<String, Object?>;

      expect(map['_schemaVersion'], 12);
    });

    test(
      'load() resolves unsupported locale to platform-default fallback',
      () async {
        final storage = PreferencesStorage();
        await storage.setString(
          _key,
          jsonEncode(<String, Object?>{'locale': 'xx'}),
        );

        final repo = PreferencesRepository(storage);
        final prefs = await repo.load(['en']);

        expect(prefs.locale, const Locale('en'));
      },
    );
  });
}
