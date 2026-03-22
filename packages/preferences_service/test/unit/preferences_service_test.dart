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

      await service.update((s) => s.copyWith(themeMode: ThemeMode.dark));

      expect(service.current.themeMode, ThemeMode.dark);
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
      await service.update((s) => s.copyWith(themeMode: ThemeMode.dark));

      final service2 = await PreferencesService.create(
        supportedCodes: _supportedCodes,
      );

      expect(service2.current.themeMode, ThemeMode.dark);
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
  });
}
