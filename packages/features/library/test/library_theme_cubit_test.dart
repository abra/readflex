import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:library_feature/src/library_theme_cubit.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

const _supportedCodes = ['en'];

void main() {
  late PreferencesService preferencesService;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    preferencesService = await PreferencesService.create(
      supportedCodes: _supportedCodes,
    );
  });

  group('LibraryThemeCubit', () {
    blocTest<LibraryThemeCubit, ThemeMode>(
      'initial state defaults to system',
      build: () => LibraryThemeCubit(preferencesService: preferencesService),
      verify: (cubit) {
        expect(cubit.state, ThemeMode.system);
      },
    );

    blocTest<LibraryThemeCubit, ThemeMode>(
      'setThemeMode emits selected mode',
      build: () => LibraryThemeCubit(preferencesService: preferencesService),
      act: (cubit) => cubit.setThemeMode(ThemeMode.dark),
      expect: () => [ThemeMode.dark],
    );

    blocTest<LibraryThemeCubit, ThemeMode>(
      'setThemeMode persists to preferences',
      build: () => LibraryThemeCubit(preferencesService: preferencesService),
      act: (cubit) => cubit.setThemeMode(ThemeMode.light),
      verify: (_) {
        expect(preferencesService.current.themeMode, ThemeMode.light);
      },
    );

    blocTest<LibraryThemeCubit, ThemeMode>(
      'setThemeMode does not emit when mode is same',
      build: () => LibraryThemeCubit(preferencesService: preferencesService),
      act: (cubit) => cubit.setThemeMode(ThemeMode.system),
      expect: () => <ThemeMode>[],
    );
  });

  group('LibraryThemeCubit reads persisted mode', () {
    blocTest<LibraryThemeCubit, ThemeMode>(
      'starts with persisted dark mode',
      setUp: () async {
        await preferencesService.update(
          (prefs) => prefs.copyWith(themeMode: ThemeMode.dark),
        );
      },
      build: () => LibraryThemeCubit(preferencesService: preferencesService),
      verify: (cubit) {
        expect(cubit.state, ThemeMode.dark);
      },
    );
  });
}
