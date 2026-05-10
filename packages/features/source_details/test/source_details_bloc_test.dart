import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:book_repository/book_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:source_details/src/source_details_bloc.dart';

final _source = Book(
  id: 'source-1',
  title: 'Flutter Design Patterns',
  filePath: '/book.epub',
  format: BookFormat.epub,
  addedAt: DateTime(2026, 1, 1),
);

void main() {
  group('SourceDetailsBloc', () {
    late _FakeBookRepository repository;

    setUp(() {
      repository = _FakeBookRepository();
    });

    blocTest<SourceDetailsBloc, SourceDetailsState>(
      'loads source by id',
      setUp: () => repository.source = _source,
      build: () => SourceDetailsBloc(bookRepository: repository),
      act: (bloc) => bloc.add(const SourceDetailsLoadRequested('source-1')),
      wait: const Duration(milliseconds: 10),
      expect: () => [
        const SourceDetailsState(status: SourceDetailsStatus.loading),
        SourceDetailsState(
          status: SourceDetailsStatus.success,
          source: _source,
        ),
      ],
    );

    blocTest<SourceDetailsBloc, SourceDetailsState>(
      'refreshes initial source without returning to loading',
      setUp: () => repository.source = _source.copyWith(readingProgress: 0.4),
      build: () => SourceDetailsBloc(
        bookRepository: repository,
        initialSource: _source,
      ),
      act: (bloc) => bloc.add(const SourceDetailsLoadRequested('source-1')),
      wait: const Duration(milliseconds: 10),
      expect: () => [
        SourceDetailsState(
          status: SourceDetailsStatus.success,
          source: _source.copyWith(readingProgress: 0.4),
        ),
      ],
    );

    test('loads source file size when file exists', () async {
      final dir = await Directory.systemTemp.createTemp('source_details_test');
      final file = File('${dir.path}/book.epub');
      await file.writeAsBytes([1, 2, 3, 4]);
      repository.source = _source.copyWith(filePath: file.path);
      final bloc = SourceDetailsBloc(bookRepository: repository);

      bloc.add(const SourceDetailsLoadRequested('source-1'));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          const SourceDetailsState(status: SourceDetailsStatus.loading),
          SourceDetailsState(
            status: SourceDetailsStatus.success,
            source: _source.copyWith(filePath: file.path),
            fileSizeBytes: 4,
          ),
        ]),
      );

      await bloc.close();
      await dir.delete(recursive: true);
    });

    blocTest<SourceDetailsBloc, SourceDetailsState>(
      'emits notFound when source is missing',
      build: () => SourceDetailsBloc(bookRepository: repository),
      act: (bloc) => bloc.add(const SourceDetailsLoadRequested('missing')),
      expect: () => [
        const SourceDetailsState(status: SourceDetailsStatus.loading),
        const SourceDetailsState(status: SourceDetailsStatus.notFound),
      ],
    );

    blocTest<SourceDetailsBloc, SourceDetailsState>(
      'emits failure when repository throws',
      setUp: () => repository.shouldThrow = true,
      build: () => SourceDetailsBloc(bookRepository: repository),
      act: (bloc) => bloc.add(const SourceDetailsLoadRequested('source-1')),
      expect: () => [
        const SourceDetailsState(status: SourceDetailsStatus.loading),
        const SourceDetailsState(status: SourceDetailsStatus.failure),
      ],
    );
  });
}

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
