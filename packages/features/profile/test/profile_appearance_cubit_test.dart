import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:profile/src/profile_appearance_cubit.dart';
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

  group('ProfileAppearanceCubit', () {
    blocTest<ProfileAppearanceCubit, ProfileAppearanceState>(
      'initial state reads from preferences',
      build: () => ProfileAppearanceCubit(
        preferencesService: preferencesService,
      ),
      verify: (cubit) {
        expect(cubit.state.themeMode, ThemeMode.system);
        expect(cubit.state.readerAppearance.fontId, 'serif');
        expect(cubit.state.readerAppearance.themeId, 'paper');
      },
    );

    blocTest<ProfileAppearanceCubit, ProfileAppearanceState>(
      'setThemeMode emits new state and persists',
      build: () => ProfileAppearanceCubit(
        preferencesService: preferencesService,
      ),
      act: (cubit) => cubit.setThemeMode(ThemeMode.dark),
      expect: () => [
        isA<ProfileAppearanceState>().having(
          (s) => s.themeMode,
          'themeMode',
          ThemeMode.dark,
        ),
      ],
      verify: (_) {
        expect(preferencesService.current.themeMode, ThemeMode.dark);
      },
    );

    blocTest<ProfileAppearanceCubit, ProfileAppearanceState>(
      'setReaderFont emits updated reader appearance',
      build: () => ProfileAppearanceCubit(
        preferencesService: preferencesService,
      ),
      act: (cubit) => cubit.setReaderFont('geist'),
      expect: () => [
        isA<ProfileAppearanceState>().having(
          (s) => s.readerAppearance.fontId,
          'fontId',
          'geist',
        ),
      ],
      verify: (_) {
        expect(preferencesService.current.readerFontId, 'geist');
      },
    );

    blocTest<ProfileAppearanceCubit, ProfileAppearanceState>(
      'setReaderTheme emits updated reader appearance',
      build: () => ProfileAppearanceCubit(
        preferencesService: preferencesService,
      ),
      act: (cubit) => cubit.setReaderTheme('night'),
      expect: () => [
        isA<ProfileAppearanceState>().having(
          (s) => s.readerAppearance.themeId,
          'themeId',
          'night',
        ),
      ],
      verify: (_) {
        expect(preferencesService.current.readerThemeId, 'night');
      },
    );

    blocTest<ProfileAppearanceCubit, ProfileAppearanceState>(
      'previewTextScale emits without persisting',
      build: () => ProfileAppearanceCubit(
        preferencesService: preferencesService,
      ),
      act: (cubit) => cubit.previewTextScale(1.5),
      expect: () => [
        isA<ProfileAppearanceState>().having(
          (s) => s.readerAppearance.textScale,
          'textScale',
          1.5,
        ),
      ],
      verify: (_) {
        // Preview doesn't persist
        expect(preferencesService.current.readerTextScale, 1.0);
      },
    );

    blocTest<ProfileAppearanceCubit, ProfileAppearanceState>(
      'commitTextScale persists without emitting',
      build: () => ProfileAppearanceCubit(
        preferencesService: preferencesService,
      ),
      act: (cubit) => cubit.commitTextScale(1.3),
      expect: () => <ProfileAppearanceState>[],
      verify: (_) {
        expect(preferencesService.current.readerTextScale, 1.3);
      },
    );

    blocTest<ProfileAppearanceCubit, ProfileAppearanceState>(
      'previewLineHeight emits without persisting',
      build: () => ProfileAppearanceCubit(
        preferencesService: preferencesService,
      ),
      act: (cubit) => cubit.previewLineHeight(2.0),
      expect: () => [
        isA<ProfileAppearanceState>().having(
          (s) => s.readerAppearance.lineHeight,
          'lineHeight',
          2.0,
        ),
      ],
      verify: (_) {
        expect(preferencesService.current.readerLineHeight, 1.55);
      },
    );

    blocTest<ProfileAppearanceCubit, ProfileAppearanceState>(
      'commitLineHeight persists without emitting',
      build: () => ProfileAppearanceCubit(
        preferencesService: preferencesService,
      ),
      act: (cubit) => cubit.commitLineHeight(1.8),
      expect: () => <ProfileAppearanceState>[],
      verify: (_) {
        expect(preferencesService.current.readerLineHeight, 1.8);
      },
    );
  });
}
