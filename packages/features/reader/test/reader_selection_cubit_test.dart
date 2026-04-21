import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_selection_cubit.dart';

void main() {
  group('ReaderSelectionCubit', () {
    ReaderSelectionCubit buildCubit() => ReaderSelectionCubit();

    test('initial state: no selection', () {
      final cubit = buildCubit();
      expect(cubit.state.hasSelection, isFalse);
      expect(cubit.state.selectedText, '');
      expect(cubit.state.cfiRange, isNull);
      expect(cubit.state.pageNumber, isNull);
      expect(cubit.state.scrollOffset, isNull);
    });

    group('select', () {
      blocTest<ReaderSelectionCubit, ReaderSelectionState>(
        'sets book selection fields',
        build: buildCubit,
        act: (c) => c.select(
          text: 'Hello world',
          cfiRange: 'epubcfi(/6/4)',
          pageNumber: 42,
        ),
        expect: () => [
          isA<ReaderSelectionState>()
              .having((s) => s.hasSelection, 'hasSelection', isTrue)
              .having((s) => s.selectedText, 'selectedText', 'Hello world')
              .having((s) => s.cfiRange, 'cfiRange', 'epubcfi(/6/4)')
              .having((s) => s.pageNumber, 'pageNumber', 42)
              .having((s) => s.scrollOffset, 'scrollOffset', isNull),
        ],
      );

      blocTest<ReaderSelectionCubit, ReaderSelectionState>(
        'sets article selection fields',
        build: buildCubit,
        act: (c) => c.select(text: 'Article text', scrollOffset: 0.45),
        expect: () => [
          isA<ReaderSelectionState>()
              .having((s) => s.hasSelection, 'hasSelection', isTrue)
              .having((s) => s.selectedText, 'selectedText', 'Article text')
              .having((s) => s.scrollOffset, 'scrollOffset', 0.45)
              .having((s) => s.cfiRange, 'cfiRange', isNull)
              .having((s) => s.pageNumber, 'pageNumber', isNull),
        ],
      );
    });

    group('deselect', () {
      blocTest<ReaderSelectionCubit, ReaderSelectionState>(
        'clears all selection fields',
        build: buildCubit,
        seed: () => const ReaderSelectionState(
          selectedText: 'Some text',
          cfiRange: 'epubcfi(/6/4)',
          pageNumber: 10,
          hasSelection: true,
        ),
        act: (c) => c.deselect(),
        expect: () => [const ReaderSelectionState()],
      );

      blocTest<ReaderSelectionCubit, ReaderSelectionState>(
        'deselect on empty state emits reset state',
        build: buildCubit,
        act: (c) => c.deselect(),
        expect: () => [const ReaderSelectionState()],
      );
    });

    group('ReaderSelectionState equality', () {
      test('equal states are equal', () {
        const a = ReaderSelectionState(selectedText: 'x', hasSelection: true);
        const b = ReaderSelectionState(selectedText: 'x', hasSelection: true);
        expect(a, equals(b));
      });

      test('different text states are not equal', () {
        const a = ReaderSelectionState(selectedText: 'a');
        const b = ReaderSelectionState(selectedText: 'b');
        expect(a, isNot(equals(b)));
      });

      test('copyWith preserves unset fields', () {
        const state = ReaderSelectionState(
          selectedText: 'text',
          cfiRange: 'cfi',
          hasSelection: true,
        );
        final copy = state.copyWith(pageNumber: 5);
        expect(copy.selectedText, 'text');
        expect(copy.cfiRange, 'cfi');
        expect(copy.hasSelection, isTrue);
        expect(copy.pageNumber, 5);
      });
    });
  });
}
