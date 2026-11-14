import 'dart:async';

import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs_repository/fsrs_repository.dart';
import 'package:highlight_repository/highlight_repository.dart';
import 'package:local_storage/local_storage.dart';

void main() {
  late AppDatabase database;
  late DictionaryRepository dictionary;
  late HighlightRepository highlights;
  late FsrsRepository reviews;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    dictionary = DictionaryRepository(database: database);
    highlights = HighlightRepository(database: database);
    reviews = FsrsRepository(
      database: database,
      clock: () => DateTime.utc(2026, 11, 14, 12),
    );
    await database.booksDao.insertBook(
      BooksTableCompanion.insert(
        id: 'source',
        title: 'Original fixture',
        filePath: '/fixture.epub',
        format: 'epub',
        addedAt: '2026-11-14T12:00:00.000Z',
      ),
    );
  });

  tearDown(() async {
    dictionary.dispose();
    await database.close();
  });

  Future<_Content> save(ReviewableType type) async {
    if (type == ReviewableType.dictionary) {
      final entry = await dictionary.addEntry(
        word: 'passage',
        translation: 'A section of written text',
        sourceId: 'source',
        sourceType: SourceType.book,
      );
      return _Content(
        id: entry.id,
        type: type,
        remove: () => dictionary.deleteEntry(entry.id),
        exists: () async => await dictionary.getEntryById(entry.id) != null,
      );
    }
    final highlight = await highlights.addHighlight(
      sourceId: 'source',
      sourceType: SourceType.book,
      text: 'An original passage worth remembering.',
      cfiRange: 'epubcfi(/6/2!/4/2,/1:0,/1:12)',
    );
    return _Content(
      id: highlight.id,
      type: type,
      remove: () => highlights.deleteHighlight(highlight.id),
      exists: () async =>
          await highlights.getHighlightById(highlight.id) != null,
    );
  }

  Future<FsrsCardData> rate(_Content item) => reviews.recordReview(
    itemId: item.id,
    itemType: item.type,
    sourceId: 'source',
    rating: Rating.good,
  );

  Future<void> expectDeleted(_Content item, {int logs = 0}) async {
    expect(await item.exists(), isFalse);
    expect(await reviews.getReviewState(item.id), isNull);
    expect(await reviews.getDueItemCount(), 0);
    expect(
      await database.reviewItemsDao.reviewLogsByItem(item.id),
      hasLength(logs),
    );
  }

  for (final type in [ReviewableType.dictionary, ReviewableType.highlight]) {
    test('late $type rating cannot resurrect deleted content', () async {
      final item = await save(type);
      expect(await reviews.getDueItemCount(), 1);
      await item.remove();
      await expectLater(rate(item), throwsA(isA<NotFoundException>()));
      await expectDeleted(item);
    });

    test(
      'valid $type content still supports missing review tracking',
      () async {
        final item = await save(type);
        await reviews.deleteReviewItem(item.id);
        expect(await item.exists(), isTrue);
        final updated = await rate(item);
        expect(updated.reps, 1);
        expect((await reviews.getReviewState(item.id))?.reps, 1);
        expect(
          await database.reviewItemsDao.reviewLogsByItem(item.id),
          hasLength(1),
        );
      },
    );

    for (final deletionFirst in [true, false]) {
      test('$type overlapping delete/rating, deletion first=$deletionFirst', () async {
        final item = await save(type);
        final firstEntered = Completer<void>();
        final release = Completer<void>();
        addTearDown(() {
          if (!release.isCompleted) release.complete();
        });

        // Hold the first transaction open after its real repository operation,
        // then start the competing operation outside that transaction's zone.
        final first = database.transaction(() async {
          if (deletionFirst) {
            await item.remove();
          } else {
            await rate(item);
          }
          firstEntered.complete();
          await release.future;
        });
        // Surface an early transaction failure instead of hanging on the gate.
        await Future.any([firstEntered.future, first]);
        final second = deletionFirst
            ? expectLater(rate(item), throwsA(isA<NotFoundException>()))
            : item.remove();
        release.complete();
        await first;
        await second;

        // A completed rating remains historical data; a rejected one adds no
        // log. Neither ordering leaves current review state for deleted content.
        await expectDeleted(item, logs: deletionFirst ? 0 : 1);
      });
    }
  }

  test(
    'an image highlight never acquires text-highlight review state',
    () async {
      final highlight = await highlights.addImageAreaHighlight(
        sourceId: 'source',
        sourceType: SourceType.book,
        pageIndex: 0,
        x: .1,
        y: .2,
        width: .3,
        height: .4,
      );
      await expectLater(
        reviews.recordReview(
          itemId: highlight.id,
          itemType: ReviewableType.highlight,
          rating: Rating.good,
        ),
        throwsA(isA<NotFoundException>()),
      );
      expect(await highlights.getHighlightById(highlight.id), isNotNull);
      expect(await reviews.getReviewState(highlight.id), isNull);
      expect(await reviews.getDueItemCount(), 0);
      expect(
        await database.reviewItemsDao.reviewLogsByItem(highlight.id),
        isEmpty,
      );
    },
  );
}

class _Content {
  const _Content({
    required this.id,
    required this.type,
    required this.remove,
    required this.exists,
  });

  final String id;
  final ReviewableType type;
  final Future<void> Function() remove;
  final Future<bool> Function() exists;
}
