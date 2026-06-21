import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_highlight_focus_cubit.dart';
import 'package:reader_webview/reader_webview.dart';

void main() {
  group('ReaderHighlightFocusCubit', () {
    ReaderHighlightFocusCubit buildCubit() => ReaderHighlightFocusCubit();

    test('initial state has no focused highlight', () {
      final cubit = buildCubit();
      expect(cubit.state.hasHighlight, isFalse);
      expect(cubit.state.highlightId, isNull);
    });

    blocTest<ReaderHighlightFocusCubit, ReaderHighlightFocusState>(
      'focus stores tapped highlight metadata',
      build: buildCubit,
      act: (cubit) => cubit.focus(
        const ReaderHighlightTap(
          highlightId: 'h-1',
          position: ReaderSelectionPosition(
            left: 0.1,
            top: 0.2,
            right: 0.3,
            bottom: 0.4,
          ),
          contextText: 'Highlighted sentence.',
        ),
      ),
      expect: () => [
        isA<ReaderHighlightFocusState>()
            .having((s) => s.hasHighlight, 'hasHighlight', isTrue)
            .having((s) => s.highlightId, 'highlightId', 'h-1')
            .having(
              (s) => s.position,
              'position',
              const ReaderSelectionPosition(
                left: 0.1,
                top: 0.2,
                right: 0.3,
                bottom: 0.4,
              ),
            )
            .having(
              (s) => s.contextText,
              'contextText',
              'Highlighted sentence.',
            ),
      ],
    );

    blocTest<ReaderHighlightFocusCubit, ReaderHighlightFocusState>(
      'clear resets focus',
      build: buildCubit,
      seed: () => const ReaderHighlightFocusState(highlightId: 'h-1'),
      act: (cubit) => cubit.clear(),
      expect: () => [const ReaderHighlightFocusState()],
    );
  });
}
