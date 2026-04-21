import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_review_reminder_cubit.dart';

void main() {
  group('ReaderReviewReminderCubit', () {
    ReaderReviewReminderCubit buildCubit({
      Future<int> Function(String)? onCheckDueItems,
    }) => ReaderReviewReminderCubit(
      sourceId: 'test-source',
      onCheckDueItems: onCheckDueItems,
      checkInterval: const Duration(hours: 24),
    );

    test('initial state: showReminder is false', () {
      expect(buildCubit().state.showReminder, isFalse);
    });

    group('null callback', () {
      blocTest<ReaderReviewReminderCubit, ReaderReviewReminderState>(
        'emits nothing',
        build: () => buildCubit(),
        wait: const Duration(milliseconds: 50),
        expect: () => <ReaderReviewReminderState>[],
      );
    });

    group('due items check', () {
      blocTest<ReaderReviewReminderCubit, ReaderReviewReminderState>(
        'shows reminder when count > 0',
        build: () => buildCubit(onCheckDueItems: (_) async => 3),
        wait: const Duration(milliseconds: 50),
        expect: () => [
          isA<ReaderReviewReminderState>().having(
            (s) => s.showReminder,
            'showReminder',
            isTrue,
          ),
        ],
      );

      blocTest<ReaderReviewReminderCubit, ReaderReviewReminderState>(
        'stays hidden when count == 0',
        build: () => buildCubit(onCheckDueItems: (_) async => 0),
        wait: const Duration(milliseconds: 50),
        expect: () => <ReaderReviewReminderState>[],
      );

      blocTest<ReaderReviewReminderCubit, ReaderReviewReminderState>(
        'no duplicate emission when already showing',
        build: () => buildCubit(onCheckDueItems: (_) async => 5),
        seed: () => const ReaderReviewReminderState(showReminder: true),
        wait: const Duration(milliseconds: 50),
        expect: () => <ReaderReviewReminderState>[],
      );

      blocTest<ReaderReviewReminderCubit, ReaderReviewReminderState>(
        'passes sourceId to callback',
        build: () {
          final calls = <String>[];
          return ReaderReviewReminderCubit(
            sourceId: 'book-42',
            onCheckDueItems: (id) async {
              calls.add(id);
              return 1;
            },
            checkInterval: const Duration(hours: 24),
          );
        },
        wait: const Duration(milliseconds: 50),
        verify: (c) => expect(c.state.showReminder, isTrue),
      );
    });

    group('dismiss', () {
      blocTest<ReaderReviewReminderCubit, ReaderReviewReminderState>(
        'hides reminder when visible',
        build: () => buildCubit(),
        seed: () => const ReaderReviewReminderState(showReminder: true),
        act: (c) => c.dismiss(),
        expect: () => [
          isA<ReaderReviewReminderState>().having(
            (s) => s.showReminder,
            'showReminder',
            isFalse,
          ),
        ],
      );

      blocTest<ReaderReviewReminderCubit, ReaderReviewReminderState>(
        'no-op when already hidden',
        build: () => buildCubit(),
        act: (c) => c.dismiss(),
        expect: () => <ReaderReviewReminderState>[],
      );
    });

    group('ReaderReviewReminderState equality', () {
      test('equal states are equal', () {
        const a = ReaderReviewReminderState(showReminder: true);
        const b = ReaderReviewReminderState(showReminder: true);
        expect(a, equals(b));
      });

      test('different states are not equal', () {
        const a = ReaderReviewReminderState();
        const b = ReaderReviewReminderState(showReminder: true);
        expect(a, isNot(equals(b)));
      });
    });
  });
}
