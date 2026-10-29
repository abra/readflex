import 'dart:io';

import 'package:book_repository/book_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs_repository/fsrs_repository.dart';
import 'package:highlight_repository/highlight_repository.dart';
import 'package:local_storage/local_storage.dart';
import 'package:reader/src/reader_bloc.dart';

void main() {
  test(
    'reader delete and Undo preserve review scheduling and history',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final directory = await Directory.systemTemp.createTemp('reader-undo-');
      addTearDown(() => directory.delete(recursive: true));
      final books = BookRepository(
        database: database,
        booksDirectory: directory,
      );
      final highlights = HighlightRepository(database: database);
      var now = DateTime.utc(2026, 1, 1, 12);
      final reviews = FsrsRepository(database: database, clock: () => now);
      await database.booksDao.insertBook(
        BooksTableCompanion.insert(
          id: 'book',
          title: 'Book',
          filePath: 'book.epub',
          format: 'epub',
          addedAt: now.toIso8601String(),
        ),
      );
      final highlight = await highlights.addHighlight(
        sourceId: 'book',
        sourceType: SourceType.book,
        text: 'A quote',
        note: 'My note',
        cfiRange: 'epubcfi(/6/2)',
      );
      for (var i = 0; i < 2; i++) {
        await reviews.recordReview(
          itemId: highlight.id,
          itemType: ReviewableType.highlight,
          rating: Rating.good,
          sourceId: 'book',
        );
        now = now.add(const Duration(days: 10));
      }
      final schedule = await reviews.getReviewState(highlight.id);
      final history = await database.reviewItemsDao.reviewLogsByItem(
        highlight.id,
      );
      expect(schedule!.reps, 2);
      final reader = ReaderBloc(
        bookRepository: books,
        highlightRepository: highlights,
      );
      addTearDown(reader.close);
      Future<ReaderState> send(
        ReaderEvent event,
        bool Function(ReaderState) matches,
      ) {
        final result = reader.stream
            .firstWhere(matches)
            .timeout(const Duration(seconds: 3));
        reader.add(event);
        return result;
      }

      await send(
        const ReaderSourceLoadRequested(sourceId: 'book'),
        (s) => s.status == ReaderStatus.ready,
      );
      await send(
        ReaderHighlightDeleteRequested(highlightId: highlight.id),
        (s) => s.highlightEdits.removed.isNotEmpty,
      );
      expect(await reviews.getReviewState(highlight.id), isNull);
      await send(
        ReaderHighlightRestored(highlightId: highlight.id),
        (s) => s.highlightEdits.removed.isEmpty && s.highlights.isNotEmpty,
      );
      expect(reader.state.highlights.single, highlight);
      expect(await reviews.getReviewState(highlight.id), schedule);
      expect(
        await database.reviewItemsDao.reviewLogsByItem(highlight.id),
        history,
      );
      expect(
        (await reviews.recordReview(
          itemId: highlight.id,
          itemType: ReviewableType.highlight,
          rating: Rating.good,
        )).reps,
        3,
      );
    },
  );
}
