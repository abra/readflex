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

    test('save() then load() round-trips all fields', () async {
      final repo = PreferencesRepository(PreferencesStorage());
      const source = Preferences(
        themeMode: ThemeMode.dark,
        locale: Locale('ru'),
        contentLibraryLayoutMode: 'list',
        readerThemeId: 'night',
        readerFontId: 'geist',
        readerLayoutId: 'comfortable',
        readerTextScale: 1.3,
        readerLineHeight: 1.9,
        readerInvertImagesInDark: false,
        onboardingCompleted: true,
        hasCompletedSetup: true,
      );

      await repo.save(source);
      final loaded = await repo.load(_supportedCodes);

      expect(loaded, source);
    });

    test('save() writes JSON with expected keys', () async {
      final storage = PreferencesStorage();
      final repo = PreferencesRepository(storage);
      const prefs = Preferences(
        readerLayoutId: 'compact',
        readerInvertImagesInDark: false,
      );

      await repo.save(prefs);
      final raw = await storage.getString(_key);
      final map = jsonDecode(raw!) as Map<String, Object?>;

      expect(map['readerLayoutId'], 'compact');
      expect(map['readerInvertImagesInDark'], isFalse);
      expect(map['readerThemeId'], 'paper');
      expect(map['readerFontId'], 'serif');
      expect(map['readerTextScale'], 1.0);
      expect(map['readerLineHeight'], 1.55);
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
            'contentLibraryLayoutMode': 'grid',
            'readerThemeId': 'paper',
            'readerFontId': 'serif',
            'readerTextScale': 1.0,
            'readerLineHeight': 1.55,
            'onboardingCompleted': true,
            'hasCompletedSetup': true,
            // no readerLayoutId, no readerInvertImagesInDark
          }),
        );

        final repo = PreferencesRepository(storage);
        final prefs = await repo.load(_supportedCodes);

        expect(prefs.themeMode, ThemeMode.dark);
        expect(prefs.readerLayoutId, 'standard');
        expect(prefs.readerInvertImagesInDark, isTrue);
      },
    );

    test('load() falls back to defaults on corrupt JSON', () async {
      final storage = PreferencesStorage();
      await storage.setString(_key, 'not valid json');

      final repo = PreferencesRepository(storage);
      final prefs = await repo.load(_supportedCodes);

      expect(prefs, const Preferences());
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
