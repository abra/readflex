import 'package:bloc_test/bloc_test.dart';
import 'package:book_repository/book_repository.dart';
import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flashcard_repository/flashcard_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:highlight_repository/highlight_repository.dart';
import 'package:source_details/src/source_details_bloc.dart';

final _source = Book(
  id: 'source-1',
  title: 'Flutter Design Patterns',
  filePath: '/book.epub',
  format: BookFormat.epub,
  addedAt: DateTime(2026, 1, 1),
);

LibrarySource _librarySource(Book source) => LibrarySource.fromBook(source);

void main() {
  group('SourceDetailsBloc', () {
    late _FakeBookRepository repository;
    late _FakeHighlightRepository highlightRepository;
    late _FakeFlashcardRepository flashcardRepository;
    late _FakeDictionaryRepository dictionaryRepository;

    setUp(() {
      repository = _FakeBookRepository();
      highlightRepository = _FakeHighlightRepository();
      flashcardRepository = _FakeFlashcardRepository();
      dictionaryRepository = _FakeDictionaryRepository();
    });

    blocTest<SourceDetailsBloc, SourceDetailsState>(
      'loads source by id',
      setUp: () => repository.source = _source,
      build: () => _buildBloc(
        repository,
        highlightRepository,
        flashcardRepository,
        dictionaryRepository,
      ),
      act: (bloc) => bloc.add(const SourceDetailsLoadRequested('source-1')),
      wait: const Duration(milliseconds: 10),
      expect: () => [
        const SourceDetailsState(status: SourceDetailsStatus.loading),
        SourceDetailsState(
          status: SourceDetailsStatus.success,
          source: _librarySource(_source),
          readerBook: _source,
        ),
      ],
    );

    blocTest<SourceDetailsBloc, SourceDetailsState>(
      'loads review summary counts',
      setUp: () {
        repository.source = _source;
        highlightRepository.count = 2;
        flashcardRepository.count = 3;
        dictionaryRepository.count = 4;
      },
      build: () => _buildBloc(
        repository,
        highlightRepository,
        flashcardRepository,
        dictionaryRepository,
      ),
      act: (bloc) => bloc.add(const SourceDetailsLoadRequested('source-1')),
      wait: const Duration(milliseconds: 10),
      expect: () => [
        const SourceDetailsState(status: SourceDetailsStatus.loading),
        SourceDetailsState(
          status: SourceDetailsStatus.success,
          source: _librarySource(_source),
          readerBook: _source,
          reviewSummary: const SourceReviewSummary(
            highlightCount: 2,
            flashcardCount: 3,
            dictionaryEntryCount: 4,
          ),
        ),
      ],
    );

    blocTest<SourceDetailsBloc, SourceDetailsState>(
      'skips review summary counts for comics',
      setUp: () {
        final comic = _source.copyWith(
          filePath: '/comic.cbz',
          format: BookFormat.cbz,
        );
        repository.source = comic;
        highlightRepository.count = 2;
        flashcardRepository.count = 3;
        dictionaryRepository.count = 4;
      },
      build: () => _buildBloc(
        repository,
        highlightRepository,
        flashcardRepository,
        dictionaryRepository,
      ),
      act: (bloc) => bloc.add(const SourceDetailsLoadRequested('source-1')),
      wait: const Duration(milliseconds: 10),
      expect: () => [
        const SourceDetailsState(status: SourceDetailsStatus.loading),
        SourceDetailsState(
          status: SourceDetailsStatus.success,
          source: _librarySource(repository.source!),
          readerBook: repository.source,
        ),
      ],
      verify: (_) {
        expect(highlightRepository.callCount, 0);
        expect(flashcardRepository.callCount, 0);
        expect(dictionaryRepository.callCount, 0);
      },
    );

    blocTest<SourceDetailsBloc, SourceDetailsState>(
      'refreshes initial source without returning to loading',
      setUp: () => repository.source = _source.copyWith(readingProgress: 0.4),
      build: () => _buildBloc(
        repository,
        highlightRepository,
        flashcardRepository,
        dictionaryRepository,
        initialSource: _librarySource(_source),
      ),
      act: (bloc) => bloc.add(const SourceDetailsLoadRequested('source-1')),
      wait: const Duration(milliseconds: 10),
      expect: () => [
        SourceDetailsState(
          status: SourceDetailsStatus.success,
          source: _librarySource(_source.copyWith(readingProgress: 0.4)),
          readerBook: _source.copyWith(readingProgress: 0.4),
        ),
      ],
    );

    blocTest<SourceDetailsBloc, SourceDetailsState>(
      'emits notFound when source is missing',
      build: () => _buildBloc(
        repository,
        highlightRepository,
        flashcardRepository,
        dictionaryRepository,
      ),
      act: (bloc) => bloc.add(const SourceDetailsLoadRequested('missing')),
      expect: () => [
        const SourceDetailsState(status: SourceDetailsStatus.loading),
        const SourceDetailsState(status: SourceDetailsStatus.notFound),
      ],
    );

    blocTest<SourceDetailsBloc, SourceDetailsState>(
      'emits failure when repository throws',
      setUp: () => repository.shouldThrow = true,
      build: () => _buildBloc(
        repository,
        highlightRepository,
        flashcardRepository,
        dictionaryRepository,
      ),
      act: (bloc) => bloc.add(const SourceDetailsLoadRequested('source-1')),
      expect: () => [
        const SourceDetailsState(status: SourceDetailsStatus.loading),
        const SourceDetailsState(status: SourceDetailsStatus.failure),
      ],
    );
  });
}

SourceDetailsBloc _buildBloc(
  _FakeBookRepository bookRepository,
  _FakeHighlightRepository highlightRepository,
  _FakeFlashcardRepository flashcardRepository,
  _FakeDictionaryRepository dictionaryRepository, {
  LibrarySource? initialSource,
}) => SourceDetailsBloc(
  bookRepository: bookRepository,
  highlightRepository: highlightRepository,
  flashcardRepository: flashcardRepository,
  dictionaryRepository: dictionaryRepository,
  initialSource: initialSource,
);

class _FakeBookRepository implements BookRepository {
  Book? source;
  bool shouldThrow = false;

  @override
  Future<Book?> getBookById(String id) async {
    if (shouldThrow) throw StorageException(cause: 'fake error');
    return source?.id == id ? source : null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHighlightRepository implements HighlightRepository {
  int count = 0;
  int callCount = 0;

  @override
  Future<int> getHighlightCountBySource(String sourceId) async {
    callCount++;
    return count;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFlashcardRepository implements FlashcardRepository {
  int count = 0;
  int callCount = 0;

  @override
  Future<int> getFlashcardCountByDeck(String deckId) async {
    callCount++;
    return count;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDictionaryRepository implements DictionaryRepository {
  int count = 0;
  int callCount = 0;

  @override
  Future<int> getEntryCountBySource(String sourceId) async {
    callCount++;
    return count;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
