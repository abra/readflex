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
      expect(cubit.state.normalizedSelectedText, isNull);
      expect(cubit.state.selectionKind, isNull);
      expect(cubit.state.contextText, isNull);
      expect(cubit.state.cfiRange, isNull);
      expect(cubit.state.pageNumber, isNull);
      expect(cubit.state.scrollOffset, isNull);
    });

    group('select', () {
      blocTest<ReaderSelectionCubit, ReaderSelectionState>(
        'sets book selection fields',
        build: buildCubit,
        act: (c) => c.select(
          text: 'Hello wor',
          normalizedText: 'Hello world',
          selectionKind: 'partial_word',
          contextText: 'Say Hello world again.',
          markedContextText: 'Say [[Hello wor]] again.',
          normalizedMarkedContextText: 'Say [[Hello world]] again.',
          cfiRange: 'epubcfi(/6/4)',
          normalizedCfiRange: 'epubcfi(/6/6)',
          pageNumber: 42,
        ),
        expect: () => [
          isA<ReaderSelectionState>()
              .having((s) => s.hasSelection, 'hasSelection', isTrue)
              .having((s) => s.selectedText, 'selectedText', 'Hello wor')
              .having(
                (s) => s.normalizedSelectedText,
                'normalizedSelectedText',
                'Hello world',
              )
              .having((s) => s.selectionKind, 'selectionKind', 'partial_word')
              .having(
                (s) => s.contextText,
                'contextText',
                'Say Hello world again.',
              )
              .having(
                (s) => s.markedContextText,
                'markedContextText',
                'Say [[Hello wor]] again.',
              )
              .having(
                (s) => s.normalizedMarkedContextText,
                'normalizedMarkedContextText',
                'Say [[Hello world]] again.',
              )
              .having((s) => s.cfiRange, 'cfiRange', 'epubcfi(/6/4)')
              .having(
                (s) => s.normalizedCfiRange,
                'normalizedCfiRange',
                'epubcfi(/6/6)',
              )
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
          selectedText: 'Some te',
          normalizedSelectedText: 'Some text',
          selectionKind: 'partial_word',
          contextText: 'Some text in context.',
          normalizedMarkedContextText: '[[Some text]] in context.',
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
          selectedText: 'tex',
          normalizedSelectedText: 'text',
          selectionKind: 'partial_word',
          contextText: 'context',
          markedContextText: '[[tex]]',
          normalizedMarkedContextText: '[[text]]',
          cfiRange: 'cfi',
          normalizedCfiRange: 'normalized-cfi',
          hasSelection: true,
        );
        final copy = state.copyWith(pageNumber: 5);
        expect(copy.selectedText, 'tex');
        expect(copy.normalizedSelectedText, 'text');
        expect(copy.selectionKind, 'partial_word');
        expect(copy.contextText, 'context');
        expect(copy.markedContextText, '[[tex]]');
        expect(copy.normalizedMarkedContextText, '[[text]]');
        expect(copy.cfiRange, 'cfi');
        expect(copy.normalizedCfiRange, 'normalized-cfi');
        expect(copy.hasSelection, isTrue);
        expect(copy.pageNumber, 5);
      });
    });
  });
}
