import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_image_selection_cubit.dart';
import 'package:reader/src/reader_selection.dart';

void main() {
  group('ReaderImageSelectionCubit', () {
    blocTest<ReaderImageSelectionCubit, ReaderImageSelectionState>(
      'select stores image area selection metadata',
      build: ReaderImageSelectionCubit.new,
      act: (cubit) => cubit.select(
        pageIndex: 2,
        rect: const ReaderImageAreaRect(
          x: 0.1,
          y: 0.2,
          width: 0.3,
          height: 0.4,
        ),
        position: const ReaderSelectionPosition(
          left: 0.2,
          top: 0.3,
          right: 0.5,
          bottom: 0.6,
        ),
        progress: 0.25,
        chapterTitle: '0003.jpg',
      ),
      expect: () => [
        const ReaderImageSelectionState(
          pageIndex: 2,
          rect: ReaderImageAreaRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4),
          position: ReaderSelectionPosition(
            left: 0.2,
            top: 0.3,
            right: 0.5,
            bottom: 0.6,
          ),
          progress: 0.25,
          chapterTitle: '0003.jpg',
          hasSelection: true,
          selectionId: 1,
        ),
      ],
    );

    blocTest<ReaderImageSelectionCubit, ReaderImageSelectionState>(
      'deselect clears image area selection',
      build: ReaderImageSelectionCubit.new,
      seed: () => const ReaderImageSelectionState(
        pageIndex: 2,
        rect: ReaderImageAreaRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4),
        hasSelection: true,
      ),
      act: (cubit) => cubit.deselect(),
      expect: () => [const ReaderImageSelectionState()],
    );

    test(
      'committing preserves adjustment until the engine ends the gesture',
      () {
        final cubit = ReaderImageSelectionCubit();
        addTearDown(cubit.close);
        cubit.setAdjustment(true);
        expect(cubit.state.isAdjusting, isTrue);
        expect(cubit.state.hasSelection, isFalse);
        expect(cubit.state.selectionId, 0);
        const rect = ReaderImageAreaRect(x: .1, y: .2, width: .3, height: .4);
        cubit.select(
          pageIndex: 2,
          rect: rect,
          progress: .5,
          chapterTitle: 'Page',
        );
        expect(cubit.state.hasSelection, isTrue);
        expect(cubit.state.isAdjusting, isTrue);
        final selectionId = cubit.state.selectionId;
        expect(selectionId, greaterThan(0));
        cubit.setAdjustment(false);
        expect(cubit.state.isAdjusting, isFalse);
        expect(cubit.state.rect, rect);
        expect(cubit.state.pageIndex, 2);
        expect(cubit.state.progress, .5);
        expect(cubit.state.chapterTitle, 'Page');
        expect(cubit.state.selectionId, selectionId);
      },
    );

    blocTest<ReaderImageSelectionCubit, ReaderImageSelectionState>(
      'duplicate boundaries emit once and cancellation resets every field',
      build: ReaderImageSelectionCubit.new,
      seed: () => const ReaderImageSelectionState(
        pageIndex: 1,
        rect: ReaderImageAreaRect(x: .1, y: .2, width: .3, height: .4),
        hasSelection: true,
      ),
      act: (cubit) => cubit
        ..setAdjustment(true)
        ..setAdjustment(true)
        ..deselect()
        ..setAdjustment(false),
      expect: () => [
        const ReaderImageSelectionState(
          pageIndex: 1,
          rect: ReaderImageAreaRect(x: .1, y: .2, width: .3, height: .4),
          hasSelection: true,
          isAdjusting: true,
        ),
        const ReaderImageSelectionState(),
      ],
    );

    test('late engine callbacks after closing do nothing', () async {
      final cubit = ReaderImageSelectionCubit();
      await cubit.close();
      cubit.setAdjustment(true);
      cubit.select(
        pageIndex: 0,
        rect: const ReaderImageAreaRect(x: 0, y: 0, width: 1, height: 1),
      );
      cubit.deselect();
      expect(cubit.state, const ReaderImageSelectionState());
    });

    test(
      'commits keep draft identity and a new draft never reuses the cleared ID',
      () {
        final cubit = ReaderImageSelectionCubit();
        addTearDown(cubit.close);
        const rect = ReaderImageAreaRect(x: .1, y: .2, width: .3, height: .4);
        const resized = ReaderImageAreaRect(
          x: .1,
          y: .2,
          width: .4,
          height: .5,
        );
        cubit.select(pageIndex: 0, rect: rect);
        final first = cubit.state.selectionId;
        cubit.setAdjustment(true);
        cubit.select(pageIndex: 0, rect: resized);
        cubit.setAdjustment(false);
        expect(cubit.state.selectionId, first);
        cubit.deselect();
        expect(cubit.state.selectionId, 0);
        cubit.setAdjustment(true);
        expect(cubit.state.selectionId, 0);
        cubit.select(pageIndex: 0, rect: resized);
        expect(cubit.state.selectionId, greaterThan(first));
        final second = cubit.state.selectionId;
        cubit.setAdjustment(false);
        cubit.select(pageIndex: 0, rect: resized);
        expect(cubit.state.selectionId, second);
      },
    );
  });
}
