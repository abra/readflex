import 'package:bloc_test/bloc_test.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home/src/home_bloc.dart';

import 'helpers/fake_book_repository.dart';
import 'helpers/fake_flashcard_repository.dart';
import 'helpers/fake_highlight_repository.dart';

final _book = Book(
  id: '1',
  title: 'Test Book',
  filePath: '/test.epub',
  format: BookFormat.epub,
  addedAt: DateTime(2026, 1, 1),
);

final _highlight = Highlight(
  id: 'h1',
  sourceId: '1',
  sourceType: SourceType.book,
  text: 'highlighted text',
  color: HighlightColor.yellow,
  createdAt: DateTime(2026, 1, 5),
);

final _dueItem = ReviewItem(
  itemId: 'f1',
  itemType: ReviewableType.flashcard,
  fsrs: const FsrsCardData(),
);

void main() {
  group('HomeBloc', () {
    late FakeBookRepository bookRepo;
    late FakeHighlightRepository highlightRepo;
    late FakeFsrsRepository fsrsRepo;

    setUp(() {
      bookRepo = FakeBookRepository();
      highlightRepo = FakeHighlightRepository();
      fsrsRepo = FakeFsrsRepository();
    });

    blocTest<HomeBloc, HomeState>(
      'emits loading then success with stats',
      setUp: () {
        bookRepo.books = [_book];
        highlightRepo.highlights = [_highlight];
        fsrsRepo.dueItems = [_dueItem];
      },
      build: () => HomeBloc(
        bookRepository: bookRepo,
        highlightRepository: highlightRepo,
        fsrsRepository: fsrsRepo,
      ),
      act: (bloc) => bloc.add(const HomeLoadRequested()),
      expect: () => [
        const HomeState(status: HomeStatus.loading),
        HomeState(
          status: HomeStatus.success,
          recentBooks: [_book],
          totalHighlights: 1,
          dueFlashcards: 1,
        ),
      ],
    );

    blocTest<HomeBloc, HomeState>(
      'emits success with zeros when empty',
      build: () => HomeBloc(
        bookRepository: bookRepo,
        highlightRepository: highlightRepo,
        fsrsRepository: fsrsRepo,
      ),
      act: (bloc) => bloc.add(const HomeLoadRequested()),
      expect: () => [
        const HomeState(status: HomeStatus.loading),
        const HomeState(status: HomeStatus.success),
      ],
    );

    blocTest<HomeBloc, HomeState>(
      'emits failure on error',
      setUp: () => bookRepo.shouldThrow = true,
      build: () => HomeBloc(
        bookRepository: bookRepo,
        highlightRepository: highlightRepo,
        fsrsRepository: fsrsRepo,
      ),
      act: (bloc) => bloc.add(const HomeLoadRequested()),
      expect: () => [
        const HomeState(status: HomeStatus.loading),
        const HomeState(status: HomeStatus.failure),
      ],
    );

    blocTest<HomeBloc, HomeState>(
      'passes a limit to the book repository (guards against OOM)',
      // Home only surfaces the top-5 recent items; loading every book row
      // on a large library is wasteful and can OOM on low-end devices.
      build: () => HomeBloc(
        bookRepository: bookRepo,
        highlightRepository: highlightRepo,
        fsrsRepository: fsrsRepo,
      ),
      act: (bloc) => bloc.add(const HomeLoadRequested()),
      verify: (_) {
        expect(bookRepo.lastLimitPassed, isNotNull);
      },
    );
  });

  group('HomeState', () {
    test('totalSources equals book count', () {
      final state = HomeState(
        status: HomeStatus.success,
        recentBooks: [_book],
      );
      expect(state.totalSources, 1);
    });
  });
}
