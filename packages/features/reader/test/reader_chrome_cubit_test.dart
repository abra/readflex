import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_chrome_cubit.dart';

void main() {
  group('ReaderChromeCubit', () {
    ReaderChromeCubit buildCubit() => ReaderChromeCubit();

    test('initial state: chrome hidden', () {
      expect(buildCubit().state.chromeVisible, isFalse);
    });

    group('toggle', () {
      blocTest<ReaderChromeCubit, ReaderChromeState>(
        'hidden → visible',
        build: buildCubit,
        act: (c) => c.toggle(),
        expect: () => [
          isA<ReaderChromeState>().having(
            (s) => s.chromeVisible,
            'chromeVisible',
            isTrue,
          ),
        ],
      );

      blocTest<ReaderChromeCubit, ReaderChromeState>(
        'visible → hidden',
        build: buildCubit,
        seed: () => const ReaderChromeState(chromeVisible: true),
        act: (c) => c.toggle(),
        expect: () => [
          isA<ReaderChromeState>().having(
            (s) => s.chromeVisible,
            'chromeVisible',
            isFalse,
          ),
        ],
      );
    });

    group('hide', () {
      blocTest<ReaderChromeCubit, ReaderChromeState>(
        'hides when visible',
        build: buildCubit,
        seed: () => const ReaderChromeState(chromeVisible: true),
        act: (c) => c.hide(),
        expect: () => [
          isA<ReaderChromeState>().having(
            (s) => s.chromeVisible,
            'chromeVisible',
            isFalse,
          ),
        ],
      );

      blocTest<ReaderChromeCubit, ReaderChromeState>(
        'no-op when already hidden',
        build: buildCubit,
        act: (c) => c.hide(),
        expect: () => <ReaderChromeState>[],
      );
    });

    group('show', () {
      blocTest<ReaderChromeCubit, ReaderChromeState>(
        'shows when hidden',
        build: buildCubit,
        act: (c) => c.show(),
        expect: () => [
          isA<ReaderChromeState>().having(
            (s) => s.chromeVisible,
            'chromeVisible',
            isTrue,
          ),
        ],
      );

      blocTest<ReaderChromeCubit, ReaderChromeState>(
        'no-op when already visible',
        build: buildCubit,
        seed: () => const ReaderChromeState(chromeVisible: true),
        act: (c) => c.show(),
        expect: () => <ReaderChromeState>[],
      );
    });

    group('ReaderChromeState equality', () {
      test('equal states are equal', () {
        const a = ReaderChromeState(chromeVisible: true);
        const b = ReaderChromeState(chromeVisible: true);
        expect(a, equals(b));
      });

      test('different states are not equal', () {
        const a = ReaderChromeState();
        const b = ReaderChromeState(chromeVisible: true);
        expect(a, isNot(equals(b)));
      });
    });
  });
}
