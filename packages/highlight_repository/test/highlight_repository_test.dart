import 'package:domain_models/domain_models.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:highlight_repository/highlight_repository.dart';
import 'package:local_storage/local_storage.dart';

void main() {
  late AppDatabase db;
  late HighlightRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = HighlightRepository(database: db);
  });

  tearDown(() => db.close());

  group('HighlightRepository', () {
    test('addHighlight creates and returns highlight', () async {
      final h = await repo.addHighlight(
        sourceId: 's1',
        sourceType: SourceType.book,
        text: 'Selected text',
        progress: 0.42,
        chapterTitle: 'Chapter 4',
      );
      expect(h.text, 'Selected text');
      expect(h.sourceType, SourceType.book);
      expect(h.id, isNotEmpty);
      expect(h.color, HighlightColor.yellow);
      expect(h.progress, 0.42);
      expect(h.chapterTitle, 'Chapter 4');

      final fetched = await repo.getHighlightById(h.id);
      expect(fetched!.progress, 0.42);
      expect(fetched.chapterTitle, 'Chapter 4');
    });

    test('addImageAreaHighlight creates image-area highlight', () async {
      final h = await repo.addImageAreaHighlight(
        sourceId: 'comic-1',
        sourceType: SourceType.book,
        pageIndex: 2,
        x: 0.1,
        y: 0.2,
        width: 0.3,
        height: 0.4,
        note: 'Important panel',
        progress: 0.25,
        chapterTitle: '0003.jpg',
        color: HighlightColor.green,
      );

      expect(h.kind, HighlightKind.imageArea);
      expect(h.text, 'Page highlight');
      expect(h.imageArea, isNotNull);
      expect(h.imageArea!.pageIndex, 2);
      expect(h.imageArea!.x, 0.1);
      expect(h.imageArea!.y, 0.2);
      expect(h.imageArea!.width, 0.3);
      expect(h.imageArea!.height, 0.4);
      expect(h.note, 'Important panel');
      expect(h.pageNumber, 3);
      expect(h.progress, 0.25);
      expect(h.chapterTitle, '0003.jpg');
      expect(h.color, HighlightColor.green);

      final fetched = await repo.getHighlightById(h.id);
      expect(fetched, h);
      expect(fetched!.note, 'Important panel');
    });

    test('getHighlights returns all highlights', () async {
      await repo.addHighlight(
        sourceId: 's1',
        sourceType: SourceType.book,
        text: 'First',
      );
      await repo.addHighlight(
        sourceId: 's1',
        sourceType: SourceType.book,
        text: 'Second',
      );
      final highlights = await repo.getHighlights();
      expect(highlights, hasLength(2));
    });

    test('getHighlightCount returns total count', () async {
      await repo.addHighlight(
        sourceId: 's1',
        sourceType: SourceType.book,
        text: 'First',
      );
      await repo.addHighlight(
        sourceId: 's2',
        sourceType: SourceType.book,
        text: 'Second',
      );

      expect(await repo.getHighlightCount(), 2);
    });

    test('getHighlightsBySource filters correctly', () async {
      await repo.addHighlight(
        sourceId: 's1',
        sourceType: SourceType.book,
        text: 'Book highlight',
      );
      await repo.addHighlight(
        sourceId: 's2',
        sourceType: SourceType.book,
        text: 'Article highlight',
      );
      final result = await repo.getHighlightsBySource('s1');
      expect(result, hasLength(1));
      expect(result.first.text, 'Book highlight');
    });

    test('getHighlightCountBySource returns source count', () async {
      await repo.addHighlight(
        sourceId: 's1',
        sourceType: SourceType.book,
        text: 'First',
      );
      await repo.addHighlight(
        sourceId: 's1',
        sourceType: SourceType.book,
        text: 'Second',
      );
      await repo.addHighlight(
        sourceId: 's2',
        sourceType: SourceType.book,
        text: 'Other',
      );

      expect(await repo.getHighlightCountBySource('s1'), 2);
      expect(await repo.getHighlightCountBySource('missing'), 0);
    });

    test('getHighlightById returns correct highlight', () async {
      final created = await repo.addHighlight(
        sourceId: 's1',
        sourceType: SourceType.book,
        text: 'Find me',
      );
      final found = await repo.getHighlightById(created.id);
      expect(found, isNotNull);
      expect(found!.text, 'Find me');
    });

    test('getHighlightById returns null for missing id', () async {
      final found = await repo.getHighlightById('missing');
      expect(found, isNull);
    });

    test('updateHighlight persists note change', () async {
      final created = await repo.addHighlight(
        sourceId: 's1',
        sourceType: SourceType.book,
        text: 'Annotate me',
      );
      final updated = created.copyWith(note: 'My note');
      await repo.updateHighlight(updated);
      final fetched = await repo.getHighlightById(created.id);
      expect(fetched!.note, 'My note');
    });

    test('deleteHighlight removes highlight', () async {
      final created = await repo.addHighlight(
        sourceId: 's1',
        sourceType: SourceType.book,
        text: 'Delete me',
      );
      await repo.deleteHighlight(created.id);
      final highlights = await repo.getHighlights();
      expect(highlights, isEmpty);
    });

    // Co-deletion: deleting a highlight must also remove its
    // `review_items_table` row in the same transaction. Without this,
    // the highlight disappears from the UI but its FSRS row can still
    // surface in due-review queries.
    test('deleteHighlight also removes FSRS review row', () async {
      final created = await repo.addHighlight(
        sourceId: 's1',
        sourceType: SourceType.book,
        text: 'With FSRS',
      );
      // Seed an FSRS row so we can prove it gets purged.
      await db.reviewItemsDao.upsertItem(
        ReviewItemsTableCompanion.insert(
          itemId: created.id,
          itemType: ReviewableType.highlight.name,
          sourceId: const Value('s1'),
        ),
      );
      expect(await db.reviewItemsDao.byItemId(created.id), isNotNull);

      await repo.deleteHighlight(created.id);

      expect(await db.reviewItemsDao.byItemId(created.id), isNull);
      expect(await repo.getHighlights(), isEmpty);
    });

    test('deleteHighlightsBySource removes all for source', () async {
      await repo.addHighlight(
        sourceId: 's1',
        sourceType: SourceType.book,
        text: 'H1',
      );
      await repo.addHighlight(
        sourceId: 's1',
        sourceType: SourceType.book,
        text: 'H2',
      );
      await repo.addHighlight(
        sourceId: 's2',
        sourceType: SourceType.book,
        text: 'Keep',
      );
      await repo.deleteHighlightsBySource('s1');
      final all = await repo.getHighlights();
      expect(all, hasLength(1));
      expect(all.first.text, 'Keep');
    });

    // Bulk delete must also purge `review_items_table` rows tied to
    // the same source — otherwise the FSRS queue keeps surfacing
    // ghost reviews for the deleted highlights.
    test(
      'deleteHighlightsBySource also purges FSRS rows of that source',
      () async {
        final h1 = await repo.addHighlight(
          sourceId: 's1',
          sourceType: SourceType.book,
          text: 'H1',
        );
        final h2 = await repo.addHighlight(
          sourceId: 's1',
          sourceType: SourceType.book,
          text: 'H2',
        );
        final hKeep = await repo.addHighlight(
          sourceId: 's2',
          sourceType: SourceType.book,
          text: 'Keep',
        );
        for (final h in [h1, h2, hKeep]) {
          await db.reviewItemsDao.upsertItem(
            ReviewItemsTableCompanion.insert(
              itemId: h.id,
              itemType: ReviewableType.highlight.name,
              sourceId: Value(h.sourceId),
            ),
          );
        }

        await repo.deleteHighlightsBySource('s1');

        expect(await db.reviewItemsDao.byItemId(h1.id), isNull);
        expect(await db.reviewItemsDao.byItemId(h2.id), isNull);
        expect(await db.reviewItemsDao.byItemId(hKeep.id), isNotNull);
      },
    );

    test('addHighlight with custom color', () async {
      final h = await repo.addHighlight(
        sourceId: 's1',
        sourceType: SourceType.book,
        text: 'Blue text',
        color: HighlightColor.blue,
      );
      final fetched = await repo.getHighlightById(h.id);
      expect(fetched!.color, HighlightColor.blue);
    });

    test(
      'addHighlight replaces contained highlights and review rows',
      () async {
        final contained = await repo.addHighlight(
          sourceId: 's1',
          sourceType: SourceType.book,
          text: 'Small',
        );
        final keep = await repo.addHighlight(
          sourceId: 's1',
          sourceType: SourceType.book,
          text: 'Keep',
        );
        await db.reviewItemsDao.upsertItem(
          ReviewItemsTableCompanion.insert(
            itemId: contained.id,
            itemType: ReviewableType.highlight.name,
            sourceId: const Value('s1'),
          ),
        );

        final replacement = await repo.addHighlight(
          sourceId: 's1',
          sourceType: SourceType.book,
          text: 'Large',
          replaceHighlightIds: [contained.id],
        );

        final highlights = await repo.getHighlightsBySource('s1');
        expect(
          highlights.map((h) => h.id),
          containsAll([keep.id, replacement.id]),
        );
        expect(highlights.map((h) => h.id), isNot(contains(contained.id)));
        expect(await db.reviewItemsDao.byItemId(contained.id), isNull);
      },
    );

    test('addHighlight replacement ignores ids from other sources', () async {
      final other = await repo.addHighlight(
        sourceId: 'other',
        sourceType: SourceType.book,
        text: 'Other source',
      );
      await db.reviewItemsDao.upsertItem(
        ReviewItemsTableCompanion.insert(
          itemId: other.id,
          itemType: ReviewableType.highlight.name,
          sourceId: const Value('other'),
        ),
      );

      await repo.addHighlight(
        sourceId: 's1',
        sourceType: SourceType.book,
        text: 'Large',
        replaceHighlightIds: [other.id],
      );

      expect(await repo.getHighlightById(other.id), isNotNull);
      expect(await db.reviewItemsDao.byItemId(other.id), isNotNull);
    });
  });
}
