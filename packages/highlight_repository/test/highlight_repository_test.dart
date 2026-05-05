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
      );
      expect(h.text, 'Selected text');
      expect(h.sourceType, SourceType.book);
      expect(h.id, isNotEmpty);
      expect(h.color, HighlightColor.yellow);
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
    // the highlight disappears from the UI but the FSRS row keeps
    // surfacing in `getDueItems()` forever, since the DAO only checks
    // `next_review_at` and doesn't join back to the highlights table.
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
  });
}
