import 'package:bloc_test/bloc_test.dart';
import 'package:book_repository/book_repository.dart';
import 'package:library_feature/src/library_bloc.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_book_repository.dart';

final _book = Book(
  id: '1',
  title: 'Test Book',
  filePath: '/test.epub',
  format: BookFormat.epub,
  addedAt: DateTime(2026, 1, 1),
);

void main() {
  group('LibraryBloc', () {
    late FakeBookRepository repository;

    setUp(() {
      repository = FakeBookRepository();
    });

    blocTest<LibraryBloc, LibraryState>(
      'emits loading then success with books on LibraryLoadRequested',
      setUp: () => repository.seedBooks([_book]),
      build: () => LibraryBloc(bookRepository: repository),
      act: (bloc) => bloc.add(const LibraryLoadRequested()),
      expect: () => [
        LibraryState(status: LibraryStatus.loading),
        LibraryState(status: LibraryStatus.success, books: [_book]),
      ],
    );

    blocTest<LibraryBloc, LibraryState>(
      'emits success with empty list when library is empty',
      build: () => LibraryBloc(bookRepository: repository),
      act: (bloc) => bloc.add(const LibraryLoadRequested()),
      expect: () => [
        LibraryState(status: LibraryStatus.loading),
        LibraryState(status: LibraryStatus.success),
      ],
    );

    blocTest<LibraryBloc, LibraryState>(
      'emits failure when repository throws',
      setUp: () => repository.shouldThrow = true,
      build: () => LibraryBloc(bookRepository: repository),
      act: (bloc) => bloc.add(const LibraryLoadRequested()),
      expect: () => [
        LibraryState(status: LibraryStatus.loading),
        LibraryState(status: LibraryStatus.failure),
      ],
    );

    blocTest<LibraryBloc, LibraryState>(
      'debounces rapid search changes and emits only the last query',
      build: () => LibraryBloc(bookRepository: repository),
      seed: () => LibraryState(
        status: LibraryStatus.success,
        books: [_book],
      ),
      act: (bloc) {
        bloc
          ..add(const LibrarySearchQueryChanged('t'))
          ..add(const LibrarySearchQueryChanged('te'))
          ..add(const LibrarySearchQueryChanged('test'));
      },
      wait: const Duration(milliseconds: 400),
      expect: () => [
        LibraryState(
          status: LibraryStatus.success,
          books: [_book],
          searchQuery: 'test',
        ),
      ],
    );

    blocTest<LibraryBloc, LibraryState>(
      'LibrarySourceDeleted removes source and reloads',
      setUp: () => repository.seedBooks([_book]),
      build: () => LibraryBloc(bookRepository: repository),
      seed: () => LibraryState(
        status: LibraryStatus.success,
        books: [_book],
      ),
      act: (bloc) => bloc.add(
        LibrarySourceDeleted(
          _book.id,
          scope: BookDeletionScope.keepLearningData,
        ),
      ),
      expect: () => [
        LibraryState(
          status: LibraryStatus.success,
          deletionVersion: 1,
          deletionEffect: const LibraryDeletionEffect(
            version: 1,
            success: true,
            count: 1,
            singleTitle: 'Test Book',
          ),
        ),
      ],
    );

    blocTest<LibraryBloc, LibraryState>(
      'LibrarySourcesDeleted removes every id in batch and reloads once',
      setUp: () {
        final second = Book(
          id: '2',
          title: 'Second',
          filePath: '/two.epub',
          format: BookFormat.epub,
          addedAt: DateTime(2026, 1, 2),
        );
        repository.seedBooks([_book, second]);
      },
      build: () => LibraryBloc(bookRepository: repository),
      seed: () => LibraryState(
        status: LibraryStatus.success,
        books: [_book],
      ),
      act: (bloc) => bloc.add(
        const LibrarySourcesDeleted(
          {'1', '2'},
          scope: BookDeletionScope.keepLearningData,
        ),
      ),
      verify: (bloc) {
        expect(bloc.state.status, LibraryStatus.success);
        expect(bloc.state.books, isEmpty);
        expect(
          bloc.state.deletionEffect,
          const LibraryDeletionEffect(
            version: 1,
            success: true,
            count: 2,
          ),
        );
      },
    );

    // Delete completion metadata is emitted by the bloc so the screen does
    // not need a local queue to attribute toasts to overlapping deletes.
    blocTest<LibraryBloc, LibraryState>(
      'LibrarySourceDeleted emits a success deletion effect',
      setUp: () => repository.seedBooks([_book]),
      build: () => LibraryBloc(bookRepository: repository),
      seed: () => LibraryState(status: LibraryStatus.success, books: [_book]),
      act: (bloc) => bloc.add(
        LibrarySourceDeleted(
          _book.id,
          scope: BookDeletionScope.keepLearningData,
        ),
      ),
      verify: (bloc) {
        expect(bloc.state.deletionVersion, 1);
        expect(
          bloc.state.deletionEffect,
          const LibraryDeletionEffect(
            version: 1,
            success: true,
            count: 1,
            singleTitle: 'Test Book',
          ),
        );
      },
    );

    // The bulk-delete handler is resilient to per-id failure — if one id
    // throws we still attempt the rest, then re-pull the list and emit an
    // error effect without replacing the visible list with a full-screen
    // failure state.
    blocTest<LibraryBloc, LibraryState>(
      'LibrarySourcesDeleted continues on per-id failure and refetches',
      setUp: () {
        final second = Book(
          id: '2',
          title: 'Second',
          filePath: '/two.epub',
          format: BookFormat.epub,
          addedAt: DateTime(2026, 1, 2),
        );
        repository.seedBooks([_book, second]);
        repository.failOnIds = const {'1'};
      },
      build: () => LibraryBloc(bookRepository: repository),
      seed: () => LibraryState(
        status: LibraryStatus.success,
        books: [_book],
      ),
      act: (bloc) => bloc.add(
        const LibrarySourcesDeleted(
          {'1', '2'},
          scope: BookDeletionScope.keepLearningData,
        ),
      ),
      errors: () => [isA<Object>()],
      verify: (bloc) {
        expect(bloc.state.status, LibraryStatus.success);
        expect(bloc.state.deletionVersion, 1);
        expect(
          bloc.state.deletionEffect,
          const LibraryDeletionEffect(
            version: 1,
            success: false,
            count: 2,
          ),
        );
        // Id '2' was deleted even though id '1' failed.
        expect(bloc.state.books.map((b) => b.id), isNot(contains('2')));
      },
    );

    blocTest<LibraryBloc, LibraryState>(
      'LibrarySourceDeleted keeps current list visible on failure',
      setUp: () {
        repository.seedBooks([_book]);
        repository.shouldThrow = true;
      },
      build: () => LibraryBloc(bookRepository: repository),
      seed: () => LibraryState(status: LibraryStatus.success, books: [_book]),
      act: (bloc) => bloc.add(
        LibrarySourceDeleted(
          _book.id,
          scope: BookDeletionScope.keepLearningData,
        ),
      ),
      errors: () => [isA<Object>()],
      verify: (bloc) {
        expect(bloc.state.status, LibraryStatus.success);
        expect(bloc.state.books, [_book]);
        expect(bloc.state.deletionVersion, 1);
        expect(
          bloc.state.deletionEffect,
          const LibraryDeletionEffect(
            version: 1,
            success: false,
            count: 1,
            singleTitle: 'Test Book',
          ),
        );
      },
    );

    blocTest<LibraryBloc, LibraryState>(
      'LibraryLoadRequested does NOT bump deletionVersion',
      setUp: () => repository.seedBooks([_book]),
      build: () => LibraryBloc(bookRepository: repository),
      seed: () => LibraryState(deletionVersion: 5),
      act: (bloc) => bloc.add(const LibraryLoadRequested()),
      verify: (bloc) => expect(bloc.state.deletionVersion, 5),
    );

    blocTest<LibraryBloc, LibraryState>(
      'LibraryRefreshRequested does NOT bump deletionVersion',
      setUp: () => repository.seedBooks([_book]),
      build: () => LibraryBloc(bookRepository: repository),
      seed: () => LibraryState(deletionVersion: 7),
      act: (bloc) => bloc.add(const LibraryRefreshRequested()),
      verify: (bloc) => expect(bloc.state.deletionVersion, 7),
    );

    blocTest<LibraryBloc, LibraryState>(
      'concurrent delete + refresh both run sequentially and land on success',
      setUp: () => repository.seedBooks([_book]),
      build: () => LibraryBloc(bookRepository: repository),
      seed: () => LibraryState(
        status: LibraryStatus.success,
        books: [_book],
      ),
      act: (bloc) {
        // Fire both in the same tick. Default BLoC transformer is sequential:
        // the second event must wait for the first to finish, and neither
        // may leave the bloc in a dangling state.
        bloc
          ..add(
            LibrarySourceDeleted(
              _book.id,
              scope: BookDeletionScope.keepLearningData,
            ),
          )
          ..add(const LibraryRefreshRequested());
      },
      verify: (bloc) {
        expect(bloc.state.status, LibraryStatus.success);
        expect(bloc.state.books, isEmpty);
      },
    );
  });

  group('LibraryState', () {
    test(
      'visibleItems are sorted by lastOpenedAt descending with addedAt fallback',
      () {
        final recentlyOpened = Book(
          id: '1',
          title: 'Recently opened',
          filePath: '/a.epub',
          format: BookFormat.epub,
          addedAt: DateTime(2026, 1, 1),
          lastOpenedAt: DateTime(2026, 6, 2),
        );
        final neverOpenedNewest = Book(
          id: '2',
          title: 'Never opened newest',
          filePath: '/b.epub',
          format: BookFormat.epub,
          addedAt: DateTime(2026, 6, 1),
        );
        final neverOpenedOlder = Book(
          id: '3',
          title: 'Never opened older',
          filePath: '/c.epub',
          format: BookFormat.epub,
          addedAt: DateTime(2026, 3, 1),
        );

        final state = LibraryState(
          status: LibraryStatus.success,
          books: [neverOpenedOlder, neverOpenedNewest, recentlyOpened],
        );

        expect(
          state.visibleItems,
          [
            recentlyOpened,
            neverOpenedNewest,
            neverOpenedOlder,
          ].map(LibrarySource.fromBook).toList(),
        );
      },
    );

    // Earlier `visibleItems` was a getter that re-ran filter + lowercase
    // + sort on every call. BlocBuilder reads it on each rebuild, so
    // the same list was being computed dozens of times for one state.
    // The `late final` cache means the second read returns the exact
    // same `List` instance the first read produced.
    test('visibleItems is cached across reads of one state instance', () {
      final book = Book(
        id: 'b',
        title: 'Cached',
        filePath: '/c.epub',
        format: BookFormat.epub,
        addedAt: DateTime(2026, 1, 1),
      );
      final state = LibraryState(
        status: LibraryStatus.success,
        books: [book],
      );

      final firstRead = state.visibleItems;
      final secondRead = state.visibleItems;
      expect(identical(firstRead, secondRead), isTrue);
    });

    test('isEmpty is true when no books', () {
      final state = LibraryState(status: LibraryStatus.success);
      expect(state.isEmpty, isTrue);
    });
  });
}
