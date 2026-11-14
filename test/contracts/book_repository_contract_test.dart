import 'dart:io';

import 'package:book_repository/book_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_storage/local_storage.dart';

import '../../packages/features/reader/test/helpers/fake_book_repository.dart';

void main() {
  for (final useFake in [false, true]) {
    group(useFake ? 'Reader fake' : 'SQLite BookRepository', () {
      late BookRepository repository;
      late Future<void> Function() breakStorage;

      setUp(() async {
        if (useFake) {
          final fake = FakeBookRepository();
          for (final id in ['book', 'other']) {
            fake.seedBook(
              Book(
                id: id,
                title: id,
                filePath: '$id.epub',
                format: BookFormat.epub,
                addedAt: DateTime.utc(2026),
              ),
            );
          }
          repository = fake;
          breakStorage = () async => fake.shouldThrow = true;
        } else {
          final database = AppDatabase.forTesting(NativeDatabase.memory());
          addTearDown(database.close);
          for (final id in ['book', 'other']) {
            await database.booksDao.insertBook(
              BooksTableCompanion.insert(
                id: id,
                title: id,
                filePath: '$id.epub',
                format: 'epub',
                addedAt: DateTime.utc(2026).toIso8601String(),
              ),
            );
          }
          repository = BookRepository(
            database: database,
            booksDirectory: Directory.systemTemp,
          );
          breakStorage = () => database.customStatement(
            'DROP TABLE bookmarks_table',
          );
        }
      });

      Future<SourceBookmark> save({
        String sourceId = 'book',
        String cfi = 'chapter-1',
        double progress = .4,
        String? exact,
      }) => repository.addBookmark(
        sourceId: sourceId,
        sourceType: SourceType.book,
        cfi: cfi,
        content: 'A passage worth remembering',
        progress: progress,
        chapterTitle: 'Chapter One',
        anchorExact: exact,
        anchorPrefix: exact == null ? null : 'before ',
        anchorSuffix: exact == null ? null : ' after',
        anchorSectionIndex: exact == null ? null : 1,
        anchorSectionPage: exact == null ? null : 2,
        anchorVersion: exact == null ? null : 1,
      );

      test(
        'distinct locations have unique identities and reading order',
        () async {
          final later = await save(cfi: 'later', progress: .8);
          final earlier = await save(cfi: 'earlier', progress: .2);
          final middle = await save(cfi: 'middle', progress: .5);
          expect({later.id, earlier.id, middle.id}, hasLength(3));
          expect(await repository.getBookmarksBySource('book'), [
            earlier,
            middle,
            later,
          ]);
          await repository.deleteBookmarkById('book', earlier.id);
          expect(await repository.getBookmarksBySource('book'), [
            middle,
            later,
          ]);
        },
      );

      test(
        'the same anchor is idempotent, different text anchors coexist',
        () async {
          final first = await save(exact: 'first passage');
          expect(await save(exact: 'first passage'), first);
          final second = await save(exact: 'second passage');
          expect(second.id, isNot(first.id));
          expect(await repository.getBookmarksBySource('book'), [
            first,
            second,
          ]);
        },
      );

      test('stored bookmark progress stays within the document', () async {
        expect((await save(cfi: 'before', progress: -1)).progress, 0);
        expect((await save(cfi: 'after', progress: 2)).progress, 1);
      });

      test(
        'deleting by identity or location is scoped to its source',
        () async {
          final first = await save();
          final other = await save(sourceId: 'other');
          await repository.deleteBookmarkById('other', first.id);
          expect(await repository.getBookmarksBySource('book'), [first]);
          expect(await repository.getBookmarksBySource('other'), [other]);
          await repository.deleteBookmarkBySourceAndCfi('book', first.cfi);
          expect(await repository.getBookmarksBySource('book'), isEmpty);
          expect(await repository.getBookmarksBySource('other'), [other]);
        },
      );

      test('Undo preserves the full snapshot and is safe to repeat', () async {
        final saved = await save(exact: 'anchored passage');
        await repository.deleteBookmarkById('book', saved.id);
        expect(await repository.restoreBookmark(saved), saved);
        expect(await repository.restoreBookmark(saved), saved);
        expect(await repository.getBookmarksBySource('book'), [saved]);
      });

      test('a newer bookmark at the same anchor wins over old Undo', () async {
        final removed = await save(exact: 'anchored passage');
        await repository.deleteBookmarkById('book', removed.id);
        final newer = await save(exact: 'anchored passage');
        expect(newer.id, isNot(removed.id));
        expect(await repository.restoreBookmark(removed), newer);
        expect(await repository.getBookmarksBySource('book'), [newer]);
      });

      test('previous query results do not change after later writes', () async {
        final first = await save();
        final snapshot = await repository.getBookmarksBySource('book');
        await save(cfi: 'chapter-2');
        await repository.deleteBookmarkById('book', first.id);
        expect(snapshot, [first]);
      });

      test('storage failures have the repository exception type', () async {
        await breakStorage();
        await expectLater(save(), throwsA(isA<StorageException>()));
        await expectLater(
          repository.getBookmarksBySource('book'),
          throwsA(isA<StorageException>()),
        );
      });
    });
  }
}
