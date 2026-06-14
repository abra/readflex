import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:profile/src/profile_translation_cubit.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  late PreferencesService preferencesService;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    preferencesService = await PreferencesService.create(
      supportedCodes: ['en', 'ru'],
    );
  });

  group('ProfileTranslationCubit', () {
    blocTest<ProfileTranslationCubit, ProfileTranslationState>(
      'starts from current preferences',
      build: () => ProfileTranslationCubit(
        preferencesService: preferencesService,
      ),
      verify: (cubit) {
        expect(cubit.state.targetLanguageCode, 'ru');
        expect(cubit.state.sourceLanguageCode, isNull);
      },
    );

    blocTest<ProfileTranslationCubit, ProfileTranslationState>(
      'sets target language',
      build: () => ProfileTranslationCubit(
        preferencesService: preferencesService,
      ),
      act: (cubit) => cubit.setTargetLanguageCode('en'),
      expect: () => [
        const ProfileTranslationState(
          targetLanguageCode: 'en',
          sourceLanguageCode: null,
        ),
      ],
      verify: (_) {
        expect(preferencesService.current.translationTargetLanguageCode, 'en');
      },
    );

    blocTest<ProfileTranslationCubit, ProfileTranslationState>(
      'sets and clears source language',
      build: () => ProfileTranslationCubit(
        preferencesService: preferencesService,
      ),
      act: (cubit) async {
        await cubit.setSourceLanguageCode('ru');
        await cubit.setSourceLanguageCode(null);
      },
      expect: () => [
        const ProfileTranslationState(
          targetLanguageCode: 'ru',
          sourceLanguageCode: 'ru',
        ),
        const ProfileTranslationState(
          targetLanguageCode: 'ru',
          sourceLanguageCode: null,
        ),
      ],
      verify: (_) {
        expect(
          preferencesService.current.translationSourceLanguageCode,
          isNull,
        );
      },
    );
  });
}
