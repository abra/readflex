import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_storage/local_storage.dart';

void main() {
  late AppDatabase db;
  late HighlightsDao dao;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = db.highlightsDao;
  });

  tearDown(() => db.close());

  HighlightsTableCompanion _highlight({
    String id = 'h1',
    String sourceId = 's1',
    String sourceType = 'book',
    String highlightText = 'Selected text',
    String createdAt = '2026-01-01T00:00:00.000Z',
    String? nextReviewAt,
  }) => HighlightsTableCompanion.insert(
    id: id,
    sourceId: sourceId,
    sourceType: sourceType,
    highlightText: highlightText,
    createdAt: createdAt,
    nextReviewAt: Value(nextReviewAt),
  );

  test('insert and retrieve highlight', () async {
    await dao.insertHighlight(_highlight());
    final highlights = await dao.allHighlights();
    expect(highlights, hasLength(1));
    expect(highlights.first.highlightText, 'Selected text');
  });

  test('highlightsBySource filters correctly', () async {
    await dao.insertHighlight(_highlight(id: 'h1', sourceId: 's1'));
    await dao.insertHighlight(_highlight(id: 'h2', sourceId: 's2'));
    final result = await dao.highlightsBySource('s1');
    expect(result, hasLength(1));
    expect(result.first.id, 'h1');
  });

  test('deleteHighlightsBySource removes all for source', () async {
    await dao.insertHighlight(_highlight(id: 'h1', sourceId: 's1'));
    await dao.insertHighlight(_highlight(id: 'h2', sourceId: 's1'));
    await dao.insertHighlight(_highlight(id: 'h3', sourceId: 's2'));
    await dao.deleteHighlightsBySource('s1');
    final all = await dao.allHighlights();
    expect(all, hasLength(1));
    expect(all.first.id, 'h3');
  });

  test('dueHighlights returns items with null or past nextReviewAt', () async {
    await dao.insertHighlight(_highlight(id: 'h1')); // null → due
    await dao.insertHighlight(
      _highlight(id: 'h2', nextReviewAt: '2026-01-01T00:00:00.000Z'),
    ); // past → due
    await dao.insertHighlight(
      _highlight(id: 'h3', nextReviewAt: '2099-01-01T00:00:00.000Z'),
    ); // future → not due
    final due = await dao.dueHighlights('2026-06-01T00:00:00.000Z');
    expect(due, hasLength(2));
  });

  test('dueHighlightsBySource filters by source and due date', () async {
    await dao.insertHighlight(
      _highlight(id: 'h1', sourceId: 's1'),
    ); // null → due, source s1
    await dao.insertHighlight(
      _highlight(
        id: 'h2',
        sourceId: 's1',
        nextReviewAt: '2099-01-01T00:00:00.000Z',
      ),
    ); // future → not due
    await dao.insertHighlight(
      _highlight(id: 'h3', sourceId: 's2'),
    ); // null → due, wrong source
    final due = await dao.dueHighlightsBySource(
      's1',
      '2026-06-01T00:00:00.000Z',
    );
    expect(due, hasLength(1));
    expect(due.first.id, 'h1');
  });

  test('insertReviewLog persists review log', () async {
    await dao.insertHighlight(_highlight());
    await dao.insertReviewLog(
      ReviewLogsTableCompanion.insert(
        id: 'r1',
        itemId: 'h1',
        itemType: 'highlight',
        rating: 'good',
        stateBefore: 'new',
        stabilityBefore: 0.0,
        difficultyBefore: 0.0,
        retrievabilityAtReview: 0.0,
        scheduledDays: 1,
        elapsedDays: 0,
        reviewedAt: '2026-01-01T00:00:00.000Z',
      ),
    );
    // Verify by reading via the flashcardsDao which has reviewLogsByItem
    final logs = await db.flashcardsDao.reviewLogsByItem('h1');
    expect(logs, hasLength(1));
    expect(logs.first.itemType, 'highlight');
  });

  test('updateHighlight modifies note', () async {
    await dao.insertHighlight(_highlight());
    await dao.updateHighlight(
      const HighlightsTableCompanion(id: Value('h1'), note: Value('My note')),
    );
    final h = await dao.highlightById('h1');
    expect(h!.note, 'My note');
  });
}
