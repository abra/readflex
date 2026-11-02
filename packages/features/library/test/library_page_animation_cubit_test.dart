import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_feature/src/library_page_animation_cubit.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  late PreferencesService preferences;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    preferences = await PreferencesService.create(supportedCodes: ['en']);
    addTearDown(preferences.dispose);
  });

  LibraryPageAnimationCubit createCubit() =>
      LibraryPageAnimationCubit(preferencesService: preferences);

  test('initial state uses the global default', () async {
    final cubit = createCubit();
    addTearDown(cubit.close);
    expect(cubit.state, ReaderPageAnimation.cover);
  });

  test('loads the persisted global animation on creation', () async {
    await preferences.update(
      (prefs) => prefs.copyWith(readerPageAnimation: ReaderPageAnimation.slide),
    );
    final cubit = createCubit();
    addTearDown(cubit.close);
    expect(cubit.state, ReaderPageAnimation.slide);
  });

  blocTest<LibraryPageAnimationCubit, ReaderPageAnimation>(
    'publishes and persists the selection for a later launch',
    build: createCubit,
    act: (cubit) => cubit.setPageAnimation(ReaderPageAnimation.slide),
    expect: () => [ReaderPageAnimation.slide],
    verify: (_) async {
      expect(
        preferences.current.readerPageAnimation,
        ReaderPageAnimation.slide,
      );
      final reopened = await PreferencesService.create(supportedCodes: ['en']);
      addTearDown(reopened.dispose);
      expect(reopened.current.readerPageAnimation, ReaderPageAnimation.slide);
    },
  );

  blocTest<LibraryPageAnimationCubit, ReaderPageAnimation>(
    'selecting the current animation emits no duplicate state',
    build: createCubit,
    act: (cubit) => cubit.setPageAnimation(ReaderPageAnimation.cover),
    expect: () => <ReaderPageAnimation>[],
  );

  blocTest<LibraryPageAnimationCubit, ReaderPageAnimation>(
    'queued saves cannot replace the latest selected animation',
    build: createCubit,
    act: (cubit) => Future.wait([
      cubit.setPageAnimation(ReaderPageAnimation.slide),
      cubit.setPageAnimation(ReaderPageAnimation.cover),
    ]),
    expect: () => [ReaderPageAnimation.slide, ReaderPageAnimation.cover],
    verify: (cubit) {
      expect(cubit.state, ReaderPageAnimation.cover);
      expect(
        preferences.current.readerPageAnimation,
        ReaderPageAnimation.cover,
      );
    },
  );

  test('follows global changes made outside the Display sheet', () async {
    final cubit = createCubit();
    addTearDown(cubit.close);
    final changed = cubit.stream.first;
    await preferences.update(
      (prefs) => prefs.copyWith(readerPageAnimation: ReaderPageAnimation.slide),
    );
    expect(await changed, ReaderPageAnimation.slide);
    expect(cubit.state, ReaderPageAnimation.slide);
  });

  blocTest<LibraryPageAnimationCubit, ReaderPageAnimation>(
    'a rejected update restores the authoritative preference',
    build: createCubit,
    act: (cubit) async {
      await preferences.dispose();
      await cubit.setPageAnimation(ReaderPageAnimation.slide);
    },
    expect: () => [ReaderPageAnimation.slide, ReaderPageAnimation.cover],
    errors: () => [isA<StateError>()],
    verify: (_) {
      expect(
        preferences.current.readerPageAnimation,
        ReaderPageAnimation.cover,
      );
    },
  );

  test(
    'global choice applies to sources with independent appearance overrides',
    () async {
      await preferences.setReaderAppearanceOverride(
        'custom-source',
        const ReaderAppearanceOverride(textScale: 1.2),
      );
      final cubit = createCubit();
      addTearDown(cubit.close);
      await cubit.setPageAnimation(ReaderPageAnimation.slide);
      for (final sourceId in ['custom-source', 'unmodified-source']) {
        expect(
          preferences.effectiveReaderAppearanceFor(sourceId).pageAnimation,
          ReaderPageAnimation.slide,
        );
      }
      expect(
        preferences.effectiveReaderAppearanceFor('custom-source').textScale,
        1.2,
      );
    },
  );
}
