import 'package:bloc_test/bloc_test.dart';
import 'package:dictionary/src/dictionary_selection_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DictionarySelectionCubit', () {
    test('starts inactive with empty selection', () {
      final cubit = DictionarySelectionCubit();
      expect(cubit.state.isActive, isFalse);
      expect(cubit.state.count, 0);
    });

    blocTest<DictionarySelectionCubit, DictionarySelectionState>(
      'first toggle activates selection',
      build: DictionarySelectionCubit.new,
      act: (c) => c.toggle('a'),
      verify: (c) {
        expect(c.state.isActive, isTrue);
        expect(c.state.contains('a'), isTrue);
      },
    );

    blocTest<DictionarySelectionCubit, DictionarySelectionState>(
      'toggle on selected id removes it',
      build: DictionarySelectionCubit.new,
      act: (c) => c
        ..toggle('a')
        ..toggle('a'),
      verify: (c) {
        expect(c.state.isActive, isFalse);
        expect(c.state.contains('a'), isFalse);
      },
    );

    blocTest<DictionarySelectionCubit, DictionarySelectionState>(
      'multiple toggles accumulate',
      build: DictionarySelectionCubit.new,
      act: (c) => c
        ..toggle('a')
        ..toggle('b')
        ..toggle('c'),
      verify: (c) => expect(c.state.count, 3),
    );

    blocTest<DictionarySelectionCubit, DictionarySelectionState>(
      'clear empties an active selection',
      build: DictionarySelectionCubit.new,
      act: (c) => c
        ..toggle('a')
        ..toggle('b')
        ..clear(),
      verify: (c) {
        expect(c.state.isActive, isFalse);
        expect(c.state.count, 0);
      },
    );

    blocTest<DictionarySelectionCubit, DictionarySelectionState>(
      'clear is a no-op when already empty (no extra emission)',
      build: DictionarySelectionCubit.new,
      act: (c) => c.clear(),
      expect: () => <DictionarySelectionState>[],
    );
  });

  group('DictionarySelectionState equality', () {
    test('equal sets are equal regardless of insertion order', () {
      const a = DictionarySelectionState(selectedIds: {'1', '2'});
      const b = DictionarySelectionState(selectedIds: {'2', '1'});
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('different sets are not equal', () {
      const a = DictionarySelectionState(selectedIds: {'1'});
      const b = DictionarySelectionState(selectedIds: {'1', '2'});
      expect(a, isNot(b));
    });
  });
}
