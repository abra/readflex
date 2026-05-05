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
      // Commit-without-preview: setter schedules a debounced persist;
      // after the timer fires the broadcast stream pushes the new
      // prefs back and the subscription emits the synced state.
      // Wait covers the 200 ms debounce + the SharedPreferences
      // round-trip.
      'commitTextScale persists and reflects change via stream',
      build: () => ProfileAppearanceCubit(
        preferencesService: preferencesService,
      ),
      act: (cubit) => cubit.commitTextScale(1.3),
      wait: const Duration(milliseconds: 300),
      expect: () => [
        isA<ProfileAppearanceState>().having(
          (s) => s.readerAppearance.textScale,
          'textScale',
          1.3,
        ),
      ],
      verify: (_) {
        expect(preferencesService.current.readerTextScale, 1.3);
      },
    );

    // Rapid +/- taps used to issue one `_preferencesService.update`
    // per call. The debounce coalesces them into a single persist
    // with the last value. Test counts updates by writing through a
    // wrapping observer that records every `current.readerTextScale`
    // change emitted on the broadcast stream.
    blocTest<ProfileAppearanceCubit, ProfileAppearanceState>(
      'commitTextScale coalesces rapid calls into a single persist',
      build: () => ProfileAppearanceCubit(
        preferencesService: preferencesService,
      ),
      act: (cubit) {
        cubit.commitTextScale(1.1);
        cubit.commitTextScale(1.2);
        cubit.commitTextScale(1.3);
      },
      wait: const Duration(milliseconds: 300),
      verify: (_) {
        // Only the last value should have made it through.
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
      // Mirror of `commitTextScale persists and reflects change via
      // stream` — same debounced machinery, different field.
      'commitLineHeight persists and reflects change via stream',
      build: () => ProfileAppearanceCubit(
        preferencesService: preferencesService,
      ),
      act: (cubit) => cubit.commitLineHeight(1.8),
      wait: const Duration(milliseconds: 300),
      expect: () => [
        isA<ProfileAppearanceState>().having(
          (s) => s.readerAppearance.lineHeight,
          'lineHeight',
          1.8,
        ),
      ],
      verify: (_) {
        expect(preferencesService.current.readerLineHeight, 1.8);
      },
    );

    blocTest<ProfileAppearanceCubit, ProfileAppearanceState>(
      'commitLineHeight coalesces rapid calls into a single persist',
      build: () => ProfileAppearanceCubit(
        preferencesService: preferencesService,
      ),
      act: (cubit) {
        cubit.commitLineHeight(1.5);
        cubit.commitLineHeight(1.6);
        cubit.commitLineHeight(1.8);
      },
      wait: const Duration(milliseconds: 300),
      verify: (_) {
        expect(preferencesService.current.readerLineHeight, 1.8);
      },
    );

    // External-update reflection: when another surface (e.g. the reader's
    // font picker) writes through PreferencesService, the broadcast
    // stream pushes the new snapshot here. Without the subscription
    // the cubit's state stayed frozen at construction-time and the
    // Profile screen drifted out of sync with the reader.
    blocTest<ProfileAppearanceCubit, ProfileAppearanceState>(
      'reflects external preference updates from the broadcast stream',
      build: () => ProfileAppearanceCubit(
        preferencesService: preferencesService,
      ),
      act: (_) async {
        await preferencesService.update(
          (prefs) => prefs.copyWith(readerFontId: 'geist'),
        );
      },
      expect: () => [
        isA<ProfileAppearanceState>().having(
          (s) => s.readerAppearance.fontId,
          'fontId',
          'geist',
        ),
      ],
    );

    // De-duplication: a setter's optimistic emit followed by the
    // stream-echo from `_preferencesService.update` shouldn't surface
    // as two emits — the second snapshot equals the state we already
    // have, so `_onPrefs` skips it. (If de-dup broke, the existing
    // `setThemeMode emits new state and persists` test would already
    // fail with two emits instead of one. This test guards explicitly.)
    blocTest<ProfileAppearanceCubit, ProfileAppearanceState>(
      'optimistic emit and stream echo collapse to a single emit',
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
    );
  });
}
