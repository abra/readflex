import 'package:bloc_test/bloc_test.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:highlight/src/highlight_cubit.dart';

import 'helpers/fake_highlight_repository.dart';

void main() {
  late FakeHighlightRepository repository;

  setUp(() {
    repository = FakeHighlightRepository();
  });

  group('HighlightCubit', () {
    blocTest<HighlightCubit, HighlightSheetState>(
      'initial state has yellow color and idle status',
      build: () => HighlightCubit(highlightRepository: repository),
      verify: (cubit) {
        expect(cubit.state.status, HighlightSheetStatus.idle);
        expect(cubit.state.selectedColor, HighlightColor.yellow);
        expect(cubit.state.note, '');
      },
    );

    blocTest<HighlightCubit, HighlightSheetState>(
      'setColor emits state with new color',
      build: () => HighlightCubit(highlightRepository: repository),
      act: (cubit) => cubit.setColor(HighlightColor.blue),
      expect: () => [
        const HighlightSheetState(selectedColor: HighlightColor.blue),
      ],
    );

    blocTest<HighlightCubit, HighlightSheetState>(
      'setNote emits state with new note',
      build: () => HighlightCubit(highlightRepository: repository),
      act: (cubit) => cubit.setNote('My note'),
      expect: () => [
        const HighlightSheetState(note: 'My note'),
      ],
    );

    blocTest<HighlightCubit, HighlightSheetState>(
      'save emits saving then success',
      build: () => HighlightCubit(highlightRepository: repository),
      act: (cubit) => cubit.save(
        text: 'Selected text',
        sourceId: 'book-1',
        sourceType: SourceType.book,
      ),
      expect: () => [
        const HighlightSheetState(status: HighlightSheetStatus.saving),
        const HighlightSheetState(status: HighlightSheetStatus.success),
      ],
      verify: (_) {
        expect(repository.highlights, hasLength(1));
        expect(repository.highlights.first.text, 'Selected text');
        expect(repository.highlights.first.sourceId, 'book-1');
      },
    );

    blocTest<HighlightCubit, HighlightSheetState>(
      'save passes note when not empty',
      build: () => HighlightCubit(highlightRepository: repository),
      seed: () => const HighlightSheetState(note: 'Important'),
      act: (cubit) => cubit.save(
        text: 'Text',
        sourceId: 'book-1',
        sourceType: SourceType.book,
      ),
      verify: (_) {
        expect(repository.highlights.first.note, 'Important');
      },
    );

    blocTest<HighlightCubit, HighlightSheetState>(
      'save passes null note when empty',
      build: () => HighlightCubit(highlightRepository: repository),
      act: (cubit) => cubit.save(
        text: 'Text',
        sourceId: 'book-1',
        sourceType: SourceType.book,
      ),
      verify: (_) {
        expect(repository.highlights.first.note, isNull);
      },
    );

    blocTest<HighlightCubit, HighlightSheetState>(
      'save passes selected color',
      build: () => HighlightCubit(highlightRepository: repository),
      seed: () => const HighlightSheetState(selectedColor: HighlightColor.pink),
      act: (cubit) => cubit.save(
        text: 'Text',
        sourceId: 'book-1',
        sourceType: SourceType.book,
      ),
      verify: (_) {
        expect(repository.highlights.first.color, HighlightColor.pink);
      },
    );

    blocTest<HighlightCubit, HighlightSheetState>(
      'save emits saving then failure on error',
      build: () {
        repository.shouldThrow = true;
        return HighlightCubit(highlightRepository: repository);
      },
      act: (cubit) => cubit.save(
        text: 'Text',
        sourceId: 'book-1',
        sourceType: SourceType.book,
      ),
      expect: () => [
        const HighlightSheetState(status: HighlightSheetStatus.saving),
        const HighlightSheetState(status: HighlightSheetStatus.failure),
      ],
    );

    blocTest<HighlightCubit, HighlightSheetState>(
      'save passes optional location fields',
      build: () => HighlightCubit(highlightRepository: repository),
      act: (cubit) => cubit.save(
        text: 'Text',
        sourceId: 'book-1',
        sourceType: SourceType.book,
        cfiRange: 'epubcfi(/6/4)',
        pageNumber: 42,
        scrollOffset: 0.75,
      ),
      verify: (_) {
        final h = repository.highlights.first;
        expect(h.cfiRange, 'epubcfi(/6/4)');
        expect(h.pageNumber, 42);
        expect(h.scrollOffset, 0.75);
      },
    );
  });
}
