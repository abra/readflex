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
  }) => HighlightsTableCompanion.insert(
    id: id,
    sourceId: sourceId,
    sourceType: sourceType,
    highlightText: highlightText,
    createdAt: createdAt,
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

  test('updateHighlight modifies note', () async {
    await dao.insertHighlight(_highlight());
    await dao.updateHighlight(
      const HighlightsTableCompanion(id: Value('h1'), note: Value('My note')),
    );
    final h = await dao.highlightById('h1');
    expect(h!.note, 'My note');
  });
}
