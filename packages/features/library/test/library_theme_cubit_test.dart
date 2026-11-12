import 'package:bloc_test/bloc_test.dart';
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
    blocTest<LibraryThemeCubit, AppThemeMode>(
      'initial state defaults to system',
      build: () => LibraryThemeCubit(preferencesService: preferencesService),
      verify: (cubit) {
        expect(cubit.state, AppThemeMode.system);
      },
    );

    blocTest<LibraryThemeCubit, AppThemeMode>(
      'setThemeMode emits selected mode',
      build: () => LibraryThemeCubit(preferencesService: preferencesService),
      act: (cubit) => cubit.setThemeMode(AppThemeMode.dark),
      expect: () => [AppThemeMode.dark],
    );

    blocTest<LibraryThemeCubit, AppThemeMode>(
      'setThemeMode persists to preferences',
      build: () => LibraryThemeCubit(preferencesService: preferencesService),
      act: (cubit) => cubit.setThemeMode(AppThemeMode.light),
      verify: (_) {
        expect(preferencesService.current.themeMode, AppThemeMode.light);
      },
    );

    blocTest<LibraryThemeCubit, AppThemeMode>(
      'setThemeMode does not emit when mode is same',
      build: () => LibraryThemeCubit(preferencesService: preferencesService),
      act: (cubit) => cubit.setThemeMode(AppThemeMode.system),
      expect: () => <AppThemeMode>[],
    );
  });

  group('LibraryThemeCubit reads persisted mode', () {
    blocTest<LibraryThemeCubit, AppThemeMode>(
      'starts with persisted dark mode',
      setUp: () async {
        await preferencesService.update(
          (prefs) => prefs.copyWith(themeMode: AppThemeMode.dark),
        );
      },
      build: () => LibraryThemeCubit(preferencesService: preferencesService),
      verify: (cubit) {
        expect(cubit.state, AppThemeMode.dark);
      },
    );
  });
}
