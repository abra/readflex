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

  HighlightsTableCompanion makeHighlight({
    String id = 'h1',
    String sourceId = 's1',
    String sourceType = 'book',
    String kind = 'text',
    String highlightText = 'Selected text',
    String createdAt = '2026-01-01T00:00:00.000Z',
    double? progress,
    String? chapterTitle,
  }) => HighlightsTableCompanion.insert(
    id: id,
    sourceId: sourceId,
    sourceType: sourceType,
    kind: Value(kind),
    highlightText: highlightText,
    progress: Value(progress),
    chapterTitle: Value(chapterTitle),
    createdAt: createdAt,
  );

  test('insert and retrieve highlight', () async {
    await dao.insertHighlight(
      makeHighlight(progress: 0.42, chapterTitle: 'Chapter 4'),
    );
    final highlights = await dao.allHighlights();
    expect(highlights, hasLength(1));
    expect(highlights.first.highlightText, 'Selected text');
    expect(highlights.first.progress, 0.42);
    expect(highlights.first.chapterTitle, 'Chapter 4');
  });

  test('insert and retrieve image-area highlight metadata', () async {
    await dao.insertHighlight(
      HighlightsTableCompanion.insert(
        id: 'h-image',
        sourceId: 'comic-1',
        sourceType: 'book',
        kind: const Value('imageArea'),
        highlightText: 'Image highlight',
        imagePageIndex: const Value(2),
        imageAreaX: const Value(0.1),
        imageAreaY: const Value(0.2),
        imageAreaWidth: const Value(0.3),
        imageAreaHeight: const Value(0.4),
        createdAt: '2026-01-01T00:00:00.000Z',
      ),
    );

    final highlight = await dao.highlightById('h-image');

    expect(highlight, isNotNull);
    expect(highlight!.kind, 'imageArea');
    expect(highlight.imagePageIndex, 2);
    expect(highlight.imageAreaX, 0.1);
    expect(highlight.imageAreaY, 0.2);
    expect(highlight.imageAreaWidth, 0.3);
    expect(highlight.imageAreaHeight, 0.4);
  });

  test('highlightCount returns total highlight count', () async {
    await dao.insertHighlight(makeHighlight(id: 'h1', sourceId: 's1'));
    await dao.insertHighlight(makeHighlight(id: 'h2', sourceId: 's2'));

    expect(await dao.highlightCount(), 2);
  });

  test('highlightsBySource filters correctly', () async {
    await dao.insertHighlight(makeHighlight(id: 'h1', sourceId: 's1'));
    await dao.insertHighlight(makeHighlight(id: 'h2', sourceId: 's2'));
    final result = await dao.highlightsBySource('s1');
    expect(result, hasLength(1));
    expect(result.first.id, 'h1');
  });

  test('highlightCountBySource counts only source highlights', () async {
    await dao.insertHighlight(makeHighlight(id: 'h1', sourceId: 's1'));
    await dao.insertHighlight(makeHighlight(id: 'h2', sourceId: 's1'));
    await dao.insertHighlight(makeHighlight(id: 'h3', sourceId: 's2'));

    expect(await dao.highlightCountBySource('s1'), 2);
    expect(await dao.highlightCountBySource('missing'), 0);
  });

  test('deleteHighlightsBySource removes all for source', () async {
    await dao.insertHighlight(makeHighlight(id: 'h1', sourceId: 's1'));
    await dao.insertHighlight(makeHighlight(id: 'h2', sourceId: 's1'));
    await dao.insertHighlight(makeHighlight(id: 'h3', sourceId: 's2'));
    await dao.deleteHighlightsBySource('s1');
    final all = await dao.allHighlights();
    expect(all, hasLength(1));
    expect(all.first.id, 'h3');
  });

  test('updateHighlight modifies note', () async {
    await dao.insertHighlight(makeHighlight());
    await dao.updateHighlight(
      const HighlightsTableCompanion(id: Value('h1'), note: Value('My note')),
    );
    final h = await dao.highlightById('h1');
    expect(h!.note, 'My note');
  });
}
