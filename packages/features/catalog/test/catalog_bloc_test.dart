import 'package:bloc_test/bloc_test.dart';
import 'package:catalog/src/catalog_bloc.dart';
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
  group('CatalogBloc', () {
    late FakeBookRepository repository;

    setUp(() {
      repository = FakeBookRepository();
    });

    blocTest<CatalogBloc, CatalogState>(
      'emits loading then success with books on CatalogLoadRequested',
      setUp: () => repository.seedBooks([_book]),
      build: () => CatalogBloc(bookRepository: repository),
      act: (bloc) => bloc.add(const CatalogLoadRequested()),
      expect: () => [
        const CatalogState(status: CatalogStatus.loading),
        CatalogState(status: CatalogStatus.success, books: [_book]),
      ],
    );

    blocTest<CatalogBloc, CatalogState>(
      'emits success with empty list when library is empty',
      build: () => CatalogBloc(bookRepository: repository),
      act: (bloc) => bloc.add(const CatalogLoadRequested()),
      expect: () => [
        const CatalogState(status: CatalogStatus.loading),
        const CatalogState(status: CatalogStatus.success),
      ],
    );

    blocTest<CatalogBloc, CatalogState>(
      'emits failure when repository throws',
      setUp: () => repository.shouldThrow = true,
      build: () => CatalogBloc(bookRepository: repository),
      act: (bloc) => bloc.add(const CatalogLoadRequested()),
      expect: () => [
        const CatalogState(status: CatalogStatus.loading),
        const CatalogState(status: CatalogStatus.failure),
      ],
    );

    blocTest<CatalogBloc, CatalogState>(
      'CatalogBookDeleted removes book and reloads',
      setUp: () => repository.seedBooks([_book]),
      build: () => CatalogBloc(bookRepository: repository),
      seed: () => CatalogState(
        status: CatalogStatus.success,
        books: [_book],
      ),
      act: (bloc) => bloc.add(CatalogBookDeleted(_book.id)),
      expect: () => [
        const CatalogState(status: CatalogStatus.success),
      ],
    );

    blocTest<CatalogBloc, CatalogState>(
      'concurrent delete + refresh both run sequentially and land on success',
      setUp: () => repository.seedBooks([_book]),
      build: () => CatalogBloc(bookRepository: repository),
      seed: () => CatalogState(
        status: CatalogStatus.success,
        books: [_book],
      ),
      act: (bloc) {
        // Fire both in the same tick. Default BLoC transformer is sequential:
        // the second event must wait for the first to finish, and neither
        // may leave the bloc in a dangling state.
        bloc
          ..add(CatalogBookDeleted(_book.id))
          ..add(const CatalogRefreshRequested());
      },
      verify: (bloc) {
        expect(bloc.state.status, CatalogStatus.success);
        expect(bloc.state.books, isEmpty);
      },
    );
  });

  group('CatalogState', () {
    test('visibleItems are sorted by addedAt descending', () {
      final older = Book(
        id: '1',
        title: 'Older',
        filePath: '/a.epub',
        format: BookFormat.epub,
        addedAt: DateTime(2026, 1, 1),
      );
      final newer = Book(
        id: '2',
        title: 'Newer',
        filePath: '/b.epub',
        format: BookFormat.epub,
        addedAt: DateTime(2026, 6, 1),
      );

      final state = CatalogState(
        status: CatalogStatus.success,
        books: [older, newer],
      );

      expect(state.visibleItems, [newer, older]);
    });

    test('isEmpty is true when no books', () {
      const state = CatalogState(status: CatalogStatus.success);
      expect(state.isEmpty, isTrue);
    });
  });
}
