import 'package:domain_models/domain_models.dart';
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
        sourceType: SourceType.article,
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
        sourceType: SourceType.article,
        text: 'Keep',
      );
      await repo.deleteHighlightsBySource('s1');
      final all = await repo.getHighlights();
      expect(all, hasLength(1));
      expect(all.first.text, 'Keep');
    });

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
