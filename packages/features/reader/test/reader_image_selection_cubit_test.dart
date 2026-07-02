import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_image_selection_cubit.dart';
import 'package:reader_webview/reader_webview.dart';

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
      'protected clear is consumed once without changing selection state',
      () {
        final cubit = ReaderImageSelectionCubit();
        addTearDown(cubit.close);

        cubit.protectNextClear();

        expect(cubit.consumeProtectedClear(), isTrue);
        expect(cubit.consumeProtectedClear(), isFalse);
        expect(cubit.state, const ReaderImageSelectionState());
      },
    );

    test('held clear protection ignores repeated clears until released', () {
      final cubit = ReaderImageSelectionCubit();
      addTearDown(cubit.close);

      cubit.holdClearProtection();

      expect(cubit.consumeProtectedClear(), isTrue);
      expect(cubit.consumeProtectedClear(), isTrue);

      cubit.releaseClearProtection();

      expect(cubit.consumeProtectedClear(), isFalse);
    });
  });
}
