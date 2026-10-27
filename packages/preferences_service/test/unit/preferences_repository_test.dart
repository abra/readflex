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
    group('writes', () {
      test('a save of what was loaded writes nothing', () async {
        final storage = _CountingStorage();
        final first = PreferencesRepository(storage);
        await first.save(await first.load(_supportedCodes));
        expect(storage.writes, 1, reason: 'nothing stored yet');

        final next = PreferencesRepository(storage);
        await next.save(await next.load(_supportedCodes));
        expect(storage.writes, 1);
      });

      test('a change is written once', () async {
        final storage = _CountingStorage();
        final repo = PreferencesRepository(storage);
        final loaded = await repo.load(_supportedCodes);
        await repo.save(loaded);
        final changed = loaded.copyWith(themeMode: ThemeMode.dark);

        await repo.save(changed);
        await repo.save(changed);

        expect(storage.writes, 2);
        expect(
          (await PreferencesRepository(
            storage,
          ).load(_supportedCodes)).themeMode,
          ThemeMode.dark,
        );
      });

      test('an older schema is rewritten on its first save', () async {
        final storage = _CountingStorage();
        await storage.setString(_key, jsonEncode({'readerFontId': 'sans'}));
        final repo = PreferencesRepository(storage);

        await repo.save(await repo.load(_supportedCodes));

        expect(storage.writes, 2);
        final stored = jsonDecode((await storage.getString(_key))!) as Map;
        expect(stored['_schemaVersion'], greaterThan(1));
      });

      test('a failed write is tried again', () async {
        final storage = _CountingStorage();
        final repo = PreferencesRepository(storage);
        final changed = (await repo.load(
          _supportedCodes,
        )).copyWith(themeMode: ThemeMode.dark);

        storage.failNext = true;
        await expectLater(repo.save(changed), throwsA(isA<StateError>()));
        await repo.save(changed);

        expect(storage.writes, 2);
        expect(await storage.getString(_key), isNotNull);
      });
    });

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
      expect(prefs.readerSelectionTipShowCount, 0);
      expect(prefs.readerSelectionTipDismissed, isFalse);
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
        readerTrimPageMargins: false,
        readerPageColors: ReaderPageColors.original,
        readerColumns: ReaderColumns.one,
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
            trimPageMargins: true,
            pageColors: ReaderPageColors.theme,
            columns: ReaderColumns.two,
            brightnessOverride: 0.42,
          ),
        },
        onboardingCompleted: true,
        readerSelectionTipShowCount: 2,
        readerSelectionTipDismissed: true,
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
              trimPageMargins: true,
              pageColors: ReaderPageColors.theme,
              columns: ReaderColumns.two,
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
      expect(map['translationTargetLanguageCode'], 'en');
      expect(map.containsKey('translationSourceLanguageCode'), isFalse);
      expect(map['readerTextAlignment'], 'justify');
      expect(map['readerInvertImagesInDark'], isFalse);
      expect(map['readerOverrideFont'], isFalse);
      expect(map['readerOverrideColor'], isFalse);
      expect(map['readerUseBookLayout'], isFalse);
      expect(map['readerTrimPageMargins'], isTrue);
      expect(map['readerPageColors'], 'theme');
      expect(map['readerColumns'], 'auto');
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

    test('save() writes the selection tip fields under stable keys', () async {
      final storage = PreferencesStorage();
      final repo = PreferencesRepository(storage);
      await repo.save(
        const Preferences(
          readerSelectionTipShowCount: 3,
          readerSelectionTipDismissed: true,
        ),
      );

      final map =
          jsonDecode((await storage.getString(_key))!) as Map<String, Object?>;
      expect(map['readerSelectionTipShowCount'], 3);
      expect(map['readerSelectionTipDismissed'], isTrue);
    });

    test('load() keeps the selection tip count at zero or more', () async {
      final storage = PreferencesStorage();
      for (final (stored, expected) in [
        (-4, 0),
        (2.0, 2),
        (null, 0),
      ]) {
        await storage.setString(
          _key,
          jsonEncode(<String, Object?>{
            'readerSelectionTipShowCount': stored,
            'readerSelectionTipDismissed': stored == null ? null : false,
          }),
        );

        final prefs = await PreferencesRepository(storage).load(
          _supportedCodes,
        );
        expect(prefs.readerSelectionTipShowCount, expected, reason: '$stored');
        expect(prefs.readerSelectionTipDismissed, isFalse);
      }
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
        expect(prefs.readerTrimPageMargins, isTrue);
        expect(prefs.readerPageColors, ReaderPageColors.theme);
        expect(prefs.readerColumns, ReaderColumns.auto);
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

      expect(map['_schemaVersion'], 14);
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

class _CountingStorage extends PreferencesStorage {
  int writes = 0;
  bool failNext = false;

  @override
  Future<void> setString(String key, String value) {
    writes++;
    if (failNext) {
      failNext = false;
      throw StateError('write failed');
    }
    return super.setString(key, value);
  }
}
