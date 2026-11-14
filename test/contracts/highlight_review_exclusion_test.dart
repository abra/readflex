import 'dart:io';

import 'package:domain_models/domain_models.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs_repository/fsrs_repository.dart';
import 'package:highlight_repository/highlight_repository.dart';
import 'package:local_storage/local_storage.dart';

void main() {
  test(
    'Remove from review survives database reopen and startup repair',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'highlight-review-exclusion-',
      );
      final file = File('${directory.path}/readflex.db');
      var database = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(() async {
        await database.close();
        await directory.delete(recursive: true);
      });
      final now = DateTime.utc(2026, 11, 14, 12);
      await database.booksDao.insertBook(
        BooksTableCompanion.insert(
          id: 'book',
          title: 'A book with saved highlights',
          filePath: 'book.epub',
          format: 'epub',
          addedAt: now.toIso8601String(),
        ),
      );
      await database.highlightsDao.insertHighlight(
        HighlightsTableCompanion.insert(
          id: 'legacy',
          sourceId: 'book',
          sourceType: 'book',
          highlightText: 'A legacy highlight without review tracking',
          createdAt: now.toIso8601String(),
        ),
      );
      final highlights = HighlightRepository(database: database);
      final reviews = FsrsRepository(database: database, clock: () => now);
      await reviews.backfillTextHighlights();
      expect(await reviews.getReviewState('legacy'), const FsrsCardData());

      final highlight = await highlights.addHighlight(
        sourceId: 'book',
        sourceType: SourceType.book,
        text: 'A highlight the reader chooses to stop reviewing',
        cfiRange: 'epubcfi(/6/2!/4/2,/1:0,/1:49)',
      );
      final scheduled = await reviews.recordReview(
        itemId: highlight.id,
        itemType: ReviewableType.highlight,
        sourceId: 'book',
        rating: Rating.good,
      );
      expect(scheduled.reps, 1);
      expect(scheduled.nextReviewAt, isNotNull);

      // The session's Remove from review action preserves this exclusion.
      await reviews.excludeReviewItem(highlight.id);
      expect(await reviews.getReviewState(highlight.id), isNull);
      expect(await highlights.getHighlightById(highlight.id), highlight);

      await database.close();
      database = AppDatabase.forTesting(NativeDatabase(file));
      final restartedReviews = FsrsRepository(
        database: database,
        clock: () => now,
      );
      expect(await restartedReviews.getReviewState(highlight.id), isNull);

      await restartedReviews.backfillTextHighlights();
      expect(
        await HighlightRepository(
          database: database,
        ).getHighlightById(highlight.id),
        highlight,
      );
      expect(
        await restartedReviews.getReviewState('legacy'),
        const FsrsCardData(),
      );
      expect(
        await restartedReviews.getReviewState(highlight.id),
        isNull,
        reason: 'Startup repair must preserve the reader\'s review exclusion.',
      );
    },
  );

  group('excluded highlight edits', () {
    late AppDatabase database;
    late HighlightRepository highlights;
    late FsrsRepository reviews;
    final now = DateTime.utc(2026, 11, 14, 12);

    setUp(() async {
      database = AppDatabase.forTesting(NativeDatabase.memory());
      highlights = HighlightRepository(database: database);
      reviews = FsrsRepository(database: database, clock: () => now);
      await database.booksDao.insertBook(
        BooksTableCompanion.insert(
          id: 'book',
          title: 'A book with saved highlights',
          filePath: 'book.epub',
          format: 'epub',
          addedAt: now.toIso8601String(),
        ),
      );
    });
    tearDown(() => database.close());

    test(
      'same-anchor recolor and delete/Undo preserve the exclusion',
      () async {
        final highlight = await highlights.addHighlight(
          sourceId: 'book',
          sourceType: SourceType.book,
          text: 'A highlight to retain outside reviews',
          cfiRange: 'epubcfi(/6/2!/4/2,/1:0,/1:37)',
        );
        await reviews.recordReview(
          itemId: highlight.id,
          itemType: ReviewableType.highlight,
          rating: Rating.good,
        );
        await reviews.excludeReviewItem(highlight.id);
        final excluded = await database.reviewItemsDao.byItemId(highlight.id);
        final recolored = await highlights.addHighlight(
          sourceId: highlight.sourceId,
          sourceType: highlight.sourceType,
          text: highlight.text,
          cfiRange: highlight.cfiRange,
          color: HighlightColor.green,
          replaceHighlightIds: [highlight.id],
        );
        expect(recolored.id, highlight.id);
        expect(recolored.color, HighlightColor.green);
        expect(await database.reviewItemsDao.byItemId(highlight.id), excluded);

        final deletion = (await highlights.deleteHighlightForUndo(
          highlight.id,
        ))!;
        expect(deletion.reviewItem!.isExcluded, isTrue);
        expect(await database.reviewItemsDao.byItemId(highlight.id), isNull);
        expect(await highlights.restoreHighlight(deletion), recolored);
        await reviews.backfillTextHighlights();
        expect(await database.reviewItemsDao.byItemId(highlight.id), excluded);
        expect(await reviews.getReviewState(highlight.id), isNull);
        expect(await reviews.getDueItemCount(), 0);
        expect(await database.reviewItemsDao.reviewLogCount(), 1);
      },
    );

    test(
      'source cleanup removes excluded rows without affecting other sources',
      () async {
        final removed = await highlights.addHighlight(
          sourceId: 'book',
          sourceType: SourceType.book,
          text: 'A highlight on the removed source',
        );
        final retained = await highlights.addHighlight(
          sourceId: 'other-book',
          sourceType: SourceType.book,
          text: 'A highlight on another source',
        );
        await reviews.excludeReviewItem(removed.id);
        await reviews.excludeReviewItem(retained.id);

        await highlights.deleteHighlightsBySource('book');

        expect(await highlights.getHighlightById(removed.id), isNull);
        expect(await database.reviewItemsDao.byItemId(removed.id), isNull);
        expect(await highlights.getHighlightById(retained.id), retained);
        expect(
          (await database.reviewItemsDao.byItemId(retained.id))!.isExcluded,
          isTrue,
        );
        expect(await reviews.getDueItemCount(), 0);
      },
    );
  });
}
