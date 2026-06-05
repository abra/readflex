import 'dart:ui' show Locale;

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

const _supportedCodes = ['en', 'ru'];

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('PreferencesService', () {
    test(
      'create() returns default preferences when storage is empty',
      () async {
        final service = await PreferencesService.create(
          supportedCodes: _supportedCodes,
        );

        expect(service.current, const Preferences());
      },
    );

    test('update() changes current preferences', () async {
      final service = await PreferencesService.create(
        supportedCodes: _supportedCodes,
      );

      await service.update(
        (s) => s.copyWith(
          themeMode: ThemeMode.dark,
          catalogLayoutMode: 'list',
        ),
      );

      expect(service.current.themeMode, ThemeMode.dark);
      expect(service.current.catalogLayoutMode, 'list');
    });

    test('update() changes reader appearance preferences', () async {
      final service = await PreferencesService.create(
        supportedCodes: _supportedCodes,
      );

      await service.update(
        (s) => s.copyWith(
          readerThemeId: 'night',
          readerFontId: 'geist',
          readerLayoutId: 'comfortable',
          readerTextScale: 1.2,
          readerLineHeight: 1.8,
          readerSideMargin: 9,
          readerInvertImagesInDark: false,
        ),
      );

      expect(service.current.readerThemeId, 'night');
      expect(service.current.readerFontId, 'geist');
      expect(service.current.readerLayoutId, 'comfortable');
      expect(service.current.readerTextScale, 1.2);
      expect(service.current.readerLineHeight, 1.8);
      expect(service.current.readerSideMargin, 9);
      expect(service.current.readerInvertImagesInDark, isFalse);
    });

    test(
      'readerLayoutId and readerInvertImagesInDark persist across recreations',
      () async {
        final service = await PreferencesService.create(
          supportedCodes: _supportedCodes,
        );
        await service.update(
          (s) => s.copyWith(
            readerLayoutId: 'compact',
            readerInvertImagesInDark: false,
          ),
        );

        final service2 = await PreferencesService.create(
          supportedCodes: _supportedCodes,
        );

        expect(service2.current.readerLayoutId, 'compact');
        expect(service2.current.readerInvertImagesInDark, isFalse);
      },
    );

    test('override flags persist across recreations', () async {
      final service = await PreferencesService.create(
        supportedCodes: _supportedCodes,
      );
      await service.update(
        (s) => s.copyWith(
          readerOverrideFont: false,
          readerOverrideColor: false,
          readerUseBookLayout: false,
        ),
      );

      final service2 = await PreferencesService.create(
        supportedCodes: _supportedCodes,
      );

      expect(service2.current.readerOverrideFont, isFalse);
      expect(service2.current.readerOverrideColor, isFalse);
      expect(service2.current.readerUseBookLayout, isFalse);
    });

    test('readerSearchHistory persists across recreations', () async {
      final service = await PreferencesService.create(
        supportedCodes: _supportedCodes,
      );
      await service.update(
        (s) => s.copyWith(
          readerSearchHistory: ['flutter', 'design patterns'],
        ),
      );

      final service2 = await PreferencesService.create(
        supportedCodes: _supportedCodes,
      );

      expect(service2.current.readerSearchHistory, [
        'flutter',
        'design patterns',
      ]);
    });

    test('reader appearance override persists across recreations', () async {
      final service = await PreferencesService.create(
        supportedCodes: _supportedCodes,
      );
      await service.setReaderAppearanceOverride(
        'source-1',
        const ReaderAppearanceOverride(
          fontId: 'sans',
          textScale: 1.2,
          sideMargin: 9,
        ),
      );

      final service2 = await PreferencesService.create(
        supportedCodes: _supportedCodes,
      );

      final override = service2.readerAppearanceOverrideFor('source-1');
      expect(override?.fontId, 'sans');
      expect(override?.textScale, 1.2);
      expect(override?.sideMargin, 9);
      expect(service2.effectiveReaderAppearanceFor('source-1').fontId, 'sans');
    });

    test(
      'clearReaderAppearanceOverride removes stored source override',
      () async {
        final service = await PreferencesService.create(
          supportedCodes: _supportedCodes,
        );
        await service.setReaderAppearanceOverride(
          'source-1',
          const ReaderAppearanceOverride(fontId: 'sans'),
        );

        await service.clearReaderAppearanceOverride('source-1');

        expect(service.readerAppearanceOverrideFor('source-1'), isNull);
        expect(service.current.readerAppearanceOverrides, isEmpty);
      },
    );

    test('reader brightness override persists per source', () async {
      final service = await PreferencesService.create(
        supportedCodes: _supportedCodes,
      );

      await service.setReaderBrightnessOverride('source-1', 0.55);

      final service2 = await PreferencesService.create(
        supportedCodes: _supportedCodes,
      );

      expect(service2.readerBrightnessOverrideFor('source-1'), 0.55);
      expect(service2.readerBrightnessOverrideFor('source-2'), isNull);
    });

    test('reader brightness persists globally with system reset', () async {
      final service = await PreferencesService.create(
        supportedCodes: _supportedCodes,
      );

      await service.setReaderBrightness(0.55);

      final service2 = await PreferencesService.create(
        supportedCodes: _supportedCodes,
      );

      expect(service2.readerBrightness, 0.55);
      expect(service2.readerLastCustomBrightness, 0.55);

      await service2.setReaderBrightness(null);

      expect(service2.readerBrightness, isNull);
      expect(service2.readerLastCustomBrightness, 0.55);
    });

    test('reader brightness clear preserves other source overrides', () async {
      final service = await PreferencesService.create(
        supportedCodes: _supportedCodes,
      );
      await service.setReaderAppearanceOverride(
        'source-1',
        const ReaderAppearanceOverride(
          fontId: 'sans',
          brightnessOverride: 0.55,
        ),
      );

      await service.setReaderBrightnessOverride('source-1', null);

      final override = service.readerAppearanceOverrideFor('source-1');
      expect(override?.fontId, 'sans');
      expect(override?.brightnessOverride, isNull);
    });

    test('update() emits updated preferences on stream', () async {
      final service = await PreferencesService.create(
        supportedCodes: _supportedCodes,
      );

      expectLater(
        service.stream,
        emits(
          isA<Preferences>().having(
            (s) => s.themeMode,
            'themeMode',
            ThemeMode.dark,
          ),
        ),
      );

      await service.update((s) => s.copyWith(themeMode: ThemeMode.dark));
    });

    test('preferences persist across service recreations', () async {
      final service = await PreferencesService.create(
        supportedCodes: _supportedCodes,
      );
      await service.update(
        (s) => s.copyWith(
          themeMode: ThemeMode.dark,
          catalogLayoutMode: 'list',
          readerThemeId: 'mist',
          readerFontId: 'sans',
          readerTextScale: 1.1,
          readerSideMargin: 8,
        ),
      );

      final service2 = await PreferencesService.create(
        supportedCodes: _supportedCodes,
      );

      expect(service2.current.themeMode, ThemeMode.dark);
      expect(service2.current.catalogLayoutMode, 'list');
      expect(service2.current.readerThemeId, 'mist');
      expect(service2.current.readerFontId, 'sans');
      expect(service2.current.readerTextScale, 1.1);
      expect(service2.current.readerSideMargin, 8);
    });

    test('persists locale correctly', () async {
      final service = await PreferencesService.create(
        supportedCodes: _supportedCodes,
      );
      await service.update((s) => s.copyWith(locale: const Locale('ru')));

      final service2 = await PreferencesService.create(
        supportedCodes: _supportedCodes,
      );

      expect(service2.current.locale, const Locale('ru'));
    });

    test('onboardingCompleted defaults to false and persists true', () async {
      final service = await PreferencesService.create(
        supportedCodes: _supportedCodes,
      );
      expect(service.current.onboardingCompleted, isFalse);

      await service.update((s) => s.copyWith(onboardingCompleted: true));

      final service2 = await PreferencesService.create(
        supportedCodes: _supportedCodes,
      );
      expect(service2.current.onboardingCompleted, isTrue);
    });

    test('create() returns defaults when stored data is corrupted', () async {
      await PreferencesStorage().setString('app_preferences', 'not valid json');

      final service = await PreferencesService.create(
        supportedCodes: _supportedCodes,
      );

      expect(service.current, const Preferences());
    });

    test('dispose() closes the broadcast stream', () async {
      final service = await PreferencesService.create(
        supportedCodes: _supportedCodes,
      );
      var closed = false;
      final sub = service.stream.listen(
        (_) {},
        onDone: () => closed = true,
      );

      await service.dispose();

      expect(closed, isTrue);
      await sub.cancel();
    });
  });
}
