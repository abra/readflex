import 'package:bloc_test/bloc_test.dart';
import 'package:catalog/src/catalog_layout_cubit.dart';
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

  group('CatalogLayoutCubit', () {
    blocTest<CatalogLayoutCubit, CatalogLayoutMode>(
      'initial state defaults to grid',
      build: () => CatalogLayoutCubit(
        preferencesService: preferencesService,
      ),
      verify: (cubit) {
        expect(cubit.state, CatalogLayoutMode.grid);
      },
    );

    blocTest<CatalogLayoutCubit, CatalogLayoutMode>(
      'setLayoutMode emits list when switching from grid',
      build: () => CatalogLayoutCubit(
        preferencesService: preferencesService,
      ),
      act: (cubit) => cubit.setLayoutMode(CatalogLayoutMode.list),
      expect: () => [CatalogLayoutMode.list],
    );

    blocTest<CatalogLayoutCubit, CatalogLayoutMode>(
      'setLayoutMode persists to preferences',
      build: () => CatalogLayoutCubit(
        preferencesService: preferencesService,
      ),
      act: (cubit) => cubit.setLayoutMode(CatalogLayoutMode.list),
      verify: (_) {
        expect(preferencesService.current.catalogLayoutMode, 'list');
      },
    );

    blocTest<CatalogLayoutCubit, CatalogLayoutMode>(
      'setLayoutMode does not emit when mode is same',
      build: () => CatalogLayoutCubit(
        preferencesService: preferencesService,
      ),
      act: (cubit) => cubit.setLayoutMode(CatalogLayoutMode.grid),
      expect: () => <CatalogLayoutMode>[],
    );
  });

  group('CatalogLayoutCubit reads persisted mode', () {
    blocTest<CatalogLayoutCubit, CatalogLayoutMode>(
      'starts with list when preferences has list',
      setUp: () async {
        await preferencesService.update(
          (p) => p.copyWith(catalogLayoutMode: 'list'),
        );
      },
      build: () => CatalogLayoutCubit(
        preferencesService: preferencesService,
      ),
      verify: (cubit) {
        expect(cubit.state, CatalogLayoutMode.list);
      },
    );
  });

  group('CatalogLayoutModeX', () {
    test('fromId parses list', () {
      expect(
        CatalogLayoutModeX.fromId('list'),
        CatalogLayoutMode.list,
      );
    });

    test('fromId defaults to grid for unknown', () {
      expect(
        CatalogLayoutModeX.fromId('unknown'),
        CatalogLayoutMode.grid,
      );
    });

    test('fromId defaults to grid for null', () {
      expect(
        CatalogLayoutModeX.fromId(null),
        CatalogLayoutMode.grid,
      );
    });

    test('id round-trips through fromId', () {
      for (final mode in CatalogLayoutMode.values) {
        expect(CatalogLayoutModeX.fromId(mode.id), mode);
      }
    });
  });
}
