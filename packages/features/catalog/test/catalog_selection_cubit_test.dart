import 'package:bloc_test/bloc_test.dart';
import 'package:catalog/src/catalog_selection_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CatalogSelectionCubit', () {
    test('starts inactive with empty selection', () {
      final cubit = CatalogSelectionCubit();
      expect(cubit.state.isActive, isFalse);
      expect(cubit.state.count, 0);
    });

    blocTest<CatalogSelectionCubit, CatalogSelectionState>(
      'first toggle activates selection',
      build: CatalogSelectionCubit.new,
      act: (c) => c.toggle('a'),
      verify: (c) {
        expect(c.state.isActive, isTrue);
        expect(c.state.contains('a'), isTrue);
      },
    );

    blocTest<CatalogSelectionCubit, CatalogSelectionState>(
      'toggle on selected id removes it',
      build: CatalogSelectionCubit.new,
      act: (c) => c
        ..toggle('a')
        ..toggle('a'),
      verify: (c) {
        expect(c.state.isActive, isFalse);
        expect(c.state.contains('a'), isFalse);
      },
    );

    blocTest<CatalogSelectionCubit, CatalogSelectionState>(
      'multiple toggles accumulate',
      build: CatalogSelectionCubit.new,
      act: (c) => c
        ..toggle('a')
        ..toggle('b')
        ..toggle('c'),
      verify: (c) => expect(c.state.count, 3),
    );

    blocTest<CatalogSelectionCubit, CatalogSelectionState>(
      'clear empties an active selection',
      build: CatalogSelectionCubit.new,
      act: (c) => c
        ..toggle('a')
        ..toggle('b')
        ..clear(),
      verify: (c) {
        expect(c.state.isActive, isFalse);
        expect(c.state.count, 0);
      },
    );

    blocTest<CatalogSelectionCubit, CatalogSelectionState>(
      'clear is a no-op when already empty (no extra emission)',
      build: CatalogSelectionCubit.new,
      act: (c) => c.clear(),
      expect: () => <CatalogSelectionState>[],
    );
  });

  group('CatalogSelectionState equality', () {
    test('equal sets are equal regardless of insertion order', () {
      const a = CatalogSelectionState(selectedIds: {'1', '2'});
      const b = CatalogSelectionState(selectedIds: {'2', '1'});
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('different sets are not equal', () {
      const a = CatalogSelectionState(selectedIds: {'1'});
      const b = CatalogSelectionState(selectedIds: {'1', '2'});
      expect(a, isNot(b));
    });
  });
}
