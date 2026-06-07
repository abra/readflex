import 'package:bloc_test/bloc_test.dart';
import 'package:library_feature/src/library_selection_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LibrarySelectionCubit', () {
    test('starts inactive with empty selection', () {
      final cubit = LibrarySelectionCubit();
      expect(cubit.state.isActive, isFalse);
      expect(cubit.state.count, 0);
    });

    blocTest<LibrarySelectionCubit, LibrarySelectionState>(
      'first toggle activates selection',
      build: LibrarySelectionCubit.new,
      act: (c) => c.toggle('a'),
      verify: (c) {
        expect(c.state.isActive, isTrue);
        expect(c.state.contains('a'), isTrue);
      },
    );

    blocTest<LibrarySelectionCubit, LibrarySelectionState>(
      'toggle on selected id removes it',
      build: LibrarySelectionCubit.new,
      act: (c) => c
        ..toggle('a')
        ..toggle('a'),
      verify: (c) {
        expect(c.state.isActive, isFalse);
        expect(c.state.contains('a'), isFalse);
      },
    );

    blocTest<LibrarySelectionCubit, LibrarySelectionState>(
      'multiple toggles accumulate',
      build: LibrarySelectionCubit.new,
      act: (c) => c
        ..toggle('a')
        ..toggle('b')
        ..toggle('c'),
      verify: (c) => expect(c.state.count, 3),
    );

    blocTest<LibrarySelectionCubit, LibrarySelectionState>(
      'clear empties an active selection',
      build: LibrarySelectionCubit.new,
      act: (c) => c
        ..toggle('a')
        ..toggle('b')
        ..clear(),
      verify: (c) {
        expect(c.state.isActive, isFalse);
        expect(c.state.count, 0);
      },
    );

    blocTest<LibrarySelectionCubit, LibrarySelectionState>(
      'clear is a no-op when already empty (no extra emission)',
      build: LibrarySelectionCubit.new,
      act: (c) => c.clear(),
      expect: () => <LibrarySelectionState>[],
    );
  });

  group('LibrarySelectionState equality', () {
    test('equal sets are equal regardless of insertion order', () {
      const a = LibrarySelectionState(selectedIds: {'1', '2'});
      const b = LibrarySelectionState(selectedIds: {'2', '1'});
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('different sets are not equal', () {
      const a = LibrarySelectionState(selectedIds: {'1'});
      const b = LibrarySelectionState(selectedIds: {'1', '2'});
      expect(a, isNot(b));
    });
  });
}
