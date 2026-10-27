import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:practice/src/practice_settings_cubit.dart';
import 'package:practice/src/practice_settings_presets.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  late PreferencesService preferences;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    preferences = await PreferencesService.create(
      supportedCodes: const ['en', 'ru'],
    );
  });

  tearDown(() => preferences.dispose());

  group('presets', () {
    test('a stored value shows as its nearest choice', () {
      expect(nearestNewCardsPreset(0), 10);
      expect(nearestNewCardsPreset(14), 10);
      expect(nearestNewCardsPreset(15), 10);
      expect(nearestNewCardsPreset(16), 20);
      expect(nearestNewCardsPreset(50), 40);
      expect(PracticeMemoryTarget.nearest(0.7), PracticeMemoryTarget.lighter);
      expect(PracticeMemoryTarget.nearest(0.86), PracticeMemoryTarget.balanced);
      expect(PracticeMemoryTarget.nearest(0.93), PracticeMemoryTarget.stronger);
      expect(PracticeMemoryTarget.nearest(0.97), PracticeMemoryTarget.stronger);
    });

    test('the targets are the retentions Anki suggests', () {
      expect(PracticeMemoryTarget.lighter.desiredRetention, 0.8);
      expect(PracticeMemoryTarget.balanced.desiredRetention, 0.9);
      expect(PracticeMemoryTarget.stronger.desiredRetention, 0.95);
    });
  });

  group('PracticeSettingsCubit', () {
    test('starts from the stored preferences', () async {
      await preferences.update(
        (p) => p.copyWith(
          practiceNewCardsPerDay: 50,
          practiceReviewHighlights: false,
          practiceDesiredRetention: 0.8,
        ),
      );
      final cubit = PracticeSettingsCubit(preferencesService: preferences);
      addTearDown(cubit.close);

      expect(
        cubit.state,
        const PracticeSettingsState(
          newCardsPerDay: 40,
          reviewHighlights: false,
          memoryTarget: PracticeMemoryTarget.lighter,
        ),
      );
    });

    blocTest<PracticeSettingsCubit, PracticeSettingsState>(
      'each choice shows at once and is written to preferences',
      build: () => PracticeSettingsCubit(preferencesService: preferences),
      act: (cubit) async {
        await cubit.setNewCardsPerDay(40);
        await cubit.setReviewHighlights(false);
        await cubit.setMemoryTarget(PracticeMemoryTarget.stronger);
      },
      expect: () => const [
        PracticeSettingsState(
          newCardsPerDay: 40,
          reviewHighlights: true,
          memoryTarget: PracticeMemoryTarget.balanced,
        ),
        PracticeSettingsState(
          newCardsPerDay: 40,
          reviewHighlights: false,
          memoryTarget: PracticeMemoryTarget.balanced,
        ),
        PracticeSettingsState(
          newCardsPerDay: 40,
          reviewHighlights: false,
          memoryTarget: PracticeMemoryTarget.stronger,
        ),
      ],
      verify: (_) {
        final prefs = preferences.current;
        expect(prefs.practiceNewCardsPerDay, 40);
        expect(prefs.practiceReviewHighlights, isFalse);
        expect(prefs.practiceDesiredRetention, 0.95);
      },
    );

    blocTest<PracticeSettingsCubit, PracticeSettingsState>(
      'choosing what is already chosen writes nothing',
      build: () => PracticeSettingsCubit(preferencesService: preferences),
      act: (cubit) async {
        await cubit.setNewCardsPerDay(20);
        await cubit.setReviewHighlights(true);
        await cubit.setMemoryTarget(PracticeMemoryTarget.balanced);
      },
      expect: () => const <PracticeSettingsState>[],
    );

    blocTest<PracticeSettingsCubit, PracticeSettingsState>(
      'a failed write is reported and the choice goes back',
      build: () => PracticeSettingsCubit(
        preferencesService: _FailingPreferencesService(preferences),
      ),
      act: (cubit) => cubit.setMemoryTarget(PracticeMemoryTarget.lighter),
      expect: () => const [
        PracticeSettingsState(
          newCardsPerDay: 20,
          reviewHighlights: true,
          memoryTarget: PracticeMemoryTarget.lighter,
        ),
        PracticeSettingsState(
          newCardsPerDay: 20,
          reviewHighlights: true,
          memoryTarget: PracticeMemoryTarget.balanced,
        ),
      ],
      errors: () => [isA<StateError>()],
      verify: (_) => expect(preferences.current.practiceDesiredRetention, 0.9),
    );
  });
}

/// A service whose writes fail; reads come from the real one.
class _FailingPreferencesService implements PreferencesService {
  _FailingPreferencesService(this._inner);

  final PreferencesService _inner;

  @override
  Preferences get current => _inner.current;

  @override
  Future<void> update(Preferences Function(Preferences prefs) change) =>
      Future.error(StateError('storage failed'));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
