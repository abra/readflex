import 'package:bloc_test/bloc_test.dart';
import 'package:content_library/src/content_library_layout_cubit.dart';
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

  group('ContentLibraryLayoutCubit', () {
    blocTest<ContentLibraryLayoutCubit, ContentLibraryLayoutMode>(
      'initial state defaults to grid',
      build: () => ContentLibraryLayoutCubit(
        preferencesService: preferencesService,
      ),
      verify: (cubit) {
        expect(cubit.state, ContentLibraryLayoutMode.grid);
      },
    );

    blocTest<ContentLibraryLayoutCubit, ContentLibraryLayoutMode>(
      'setLayoutMode emits list when switching from grid',
      build: () => ContentLibraryLayoutCubit(
        preferencesService: preferencesService,
      ),
      act: (cubit) => cubit.setLayoutMode(ContentLibraryLayoutMode.list),
      expect: () => [ContentLibraryLayoutMode.list],
    );

    blocTest<ContentLibraryLayoutCubit, ContentLibraryLayoutMode>(
      'setLayoutMode persists to preferences',
      build: () => ContentLibraryLayoutCubit(
        preferencesService: preferencesService,
      ),
      act: (cubit) => cubit.setLayoutMode(ContentLibraryLayoutMode.list),
      verify: (_) {
        expect(preferencesService.current.contentLibraryLayoutMode, 'list');
      },
    );

    blocTest<ContentLibraryLayoutCubit, ContentLibraryLayoutMode>(
      'setLayoutMode does not emit when mode is same',
      build: () => ContentLibraryLayoutCubit(
        preferencesService: preferencesService,
      ),
      act: (cubit) => cubit.setLayoutMode(ContentLibraryLayoutMode.grid),
      expect: () => <ContentLibraryLayoutMode>[],
    );
  });

  group('ContentLibraryLayoutCubit reads persisted mode', () {
    blocTest<ContentLibraryLayoutCubit, ContentLibraryLayoutMode>(
      'starts with list when preferences has list',
      setUp: () async {
        await preferencesService.update(
          (p) => p.copyWith(contentLibraryLayoutMode: 'list'),
        );
      },
      build: () => ContentLibraryLayoutCubit(
        preferencesService: preferencesService,
      ),
      verify: (cubit) {
        expect(cubit.state, ContentLibraryLayoutMode.list);
      },
    );
  });

  group('ContentLibraryLayoutModeX', () {
    test('fromId parses list', () {
      expect(
        ContentLibraryLayoutModeX.fromId('list'),
        ContentLibraryLayoutMode.list,
      );
    });

    test('fromId defaults to grid for unknown', () {
      expect(
        ContentLibraryLayoutModeX.fromId('unknown'),
        ContentLibraryLayoutMode.grid,
      );
    });

    test('fromId defaults to grid for null', () {
      expect(
        ContentLibraryLayoutModeX.fromId(null),
        ContentLibraryLayoutMode.grid,
      );
    });

    test('id round-trips through fromId', () {
      for (final mode in ContentLibraryLayoutMode.values) {
        expect(ContentLibraryLayoutModeX.fromId(mode.id), mode);
      }
    });
  });
}
