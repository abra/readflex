import 'package:bloc_test/bloc_test.dart';
import 'package:library_feature/src/library_layout_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
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

  group('LibraryLayoutCubit', () {
    blocTest<LibraryLayoutCubit, LibraryLayoutMode>(
      'initial state defaults to grid',
      build: () => LibraryLayoutCubit(
        preferencesService: preferencesService,
      ),
      verify: (cubit) {
        expect(cubit.state, LibraryLayoutMode.grid);
      },
    );

    blocTest<LibraryLayoutCubit, LibraryLayoutMode>(
      'setLayoutMode emits list when switching from grid',
      build: () => LibraryLayoutCubit(
        preferencesService: preferencesService,
      ),
      act: (cubit) => cubit.setLayoutMode(LibraryLayoutMode.list),
      expect: () => [LibraryLayoutMode.list],
    );

    blocTest<LibraryLayoutCubit, LibraryLayoutMode>(
      'setLayoutMode persists to preferences',
      build: () => LibraryLayoutCubit(
        preferencesService: preferencesService,
      ),
      act: (cubit) => cubit.setLayoutMode(LibraryLayoutMode.list),
      verify: (_) {
        expect(preferencesService.current.libraryLayoutMode, 'list');
      },
    );

    blocTest<LibraryLayoutCubit, LibraryLayoutMode>(
      'setLayoutMode does not emit when mode is same',
      build: () => LibraryLayoutCubit(
        preferencesService: preferencesService,
      ),
      act: (cubit) => cubit.setLayoutMode(LibraryLayoutMode.grid),
      expect: () => <LibraryLayoutMode>[],
    );
  });

  group('LibraryLayoutCubit reads persisted mode', () {
    blocTest<LibraryLayoutCubit, LibraryLayoutMode>(
      'starts with list when preferences has list',
      setUp: () async {
        await preferencesService.update(
          (p) => p.copyWith(libraryLayoutMode: 'list'),
        );
      },
      build: () => LibraryLayoutCubit(
        preferencesService: preferencesService,
      ),
      verify: (cubit) {
        expect(cubit.state, LibraryLayoutMode.list);
      },
    );
  });

  group('LibraryLayoutModeX', () {
    test('fromId parses list', () {
      expect(
        LibraryLayoutModeX.fromId('list'),
        LibraryLayoutMode.list,
      );
    });

    test('fromId defaults to grid for unknown', () {
      expect(
        LibraryLayoutModeX.fromId('unknown'),
        LibraryLayoutMode.grid,
      );
    });

    test('fromId defaults to grid for null', () {
      expect(
        LibraryLayoutModeX.fromId(null),
        LibraryLayoutMode.grid,
      );
    });

    test('id round-trips through fromId', () {
      for (final mode in LibraryLayoutMode.values) {
        expect(LibraryLayoutModeX.fromId(mode.id), mode);
      }
    });
  });
}
