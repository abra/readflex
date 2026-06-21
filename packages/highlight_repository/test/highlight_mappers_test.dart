import 'package:domain_models/domain_models.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:highlight_repository/src/mappers/highlight_to_domain.dart';
import 'package:highlight_repository/src/mappers/highlight_to_storage.dart';
import 'package:local_storage/local_storage.dart';

void main() {
  final now = DateTime(2026, 4, 1);

  group('HighlightToDomain', () {
    test('maps all fields from storage to domain', () {
      final row = HighlightsTableData(
        id: 'h1',
        sourceId: 'book-1',
        sourceType: 'book',
        kind: 'text',
        highlightText: 'Important text',
        note: 'My note',
        cfiRange: 'epubcfi(/6/4)',
        pageNumber: 42,
        scrollOffset: 0.5,
        progress: 0.42,
        chapterTitle: 'Chapter 4',
        color: 'blue',
        createdAt: now.toIso8601String(),
      );

      final hl = row.toDomainModel();

      expect(hl.id, 'h1');
      expect(hl.sourceId, 'book-1');
      expect(hl.sourceType, SourceType.book);
      expect(hl.text, 'Important text');
      expect(hl.kind, HighlightKind.text);
      expect(hl.note, 'My note');
      expect(hl.cfiRange, 'epubcfi(/6/4)');
      expect(hl.pageNumber, 42);
      expect(hl.scrollOffset, 0.5);
      expect(hl.progress, 0.42);
      expect(hl.chapterTitle, 'Chapter 4');
      expect(hl.color, HighlightColor.blue);
      expect(hl.createdAt, now);
    });

    test('handles null optional fields', () {
      final row = HighlightsTableData(
        id: 'h2',
        sourceId: 'book-1',
        sourceType: 'article',
        kind: 'text',
        highlightText: 'Text',
        note: null,
        cfiRange: null,
        pageNumber: null,
        scrollOffset: null,
        progress: null,
        chapterTitle: null,
        color: 'yellow',
        createdAt: now.toIso8601String(),
      );

      final hl = row.toDomainModel();

      expect(hl.note, isNull);
      expect(hl.cfiRange, isNull);
      expect(hl.pageNumber, isNull);
      expect(hl.scrollOffset, isNull);
      expect(hl.progress, isNull);
      expect(hl.chapterTitle, isNull);
    });

    test('falls back to epoch for invalid date', () {
      final row = HighlightsTableData(
        id: 'h3',
        sourceId: 'book-1',
        sourceType: 'book',
        kind: 'text',
        highlightText: 'Text',
        note: null,
        cfiRange: null,
        pageNumber: null,
        scrollOffset: null,
        progress: null,
        chapterTitle: null,
        color: 'yellow',
        createdAt: 'bad',
      );

      expect(
        row.toDomainModel().createdAt,
        DateTime.fromMillisecondsSinceEpoch(0),
      );
    });

    test('maps image area metadata from storage to domain', () {
      final row = HighlightsTableData(
        id: 'h4',
        sourceId: 'comic-1',
        sourceType: 'book',
        kind: 'imageArea',
        highlightText: 'Image highlight',
        note: null,
        cfiRange: null,
        imagePageIndex: 3,
        imageAreaX: 0.1,
        imageAreaY: 0.2,
        imageAreaWidth: 0.3,
        imageAreaHeight: 0.4,
        pageNumber: 4,
        scrollOffset: null,
        progress: 0.5,
        chapterTitle: '0004.jpg',
        color: 'green',
        createdAt: now.toIso8601String(),
      );

      final hl = row.toDomainModel();

      expect(hl.kind, HighlightKind.imageArea);
      expect(hl.imageArea, isNotNull);
      expect(hl.imageArea!.pageIndex, 3);
      expect(hl.imageArea!.x, 0.1);
      expect(hl.imageArea!.y, 0.2);
      expect(hl.imageArea!.width, 0.3);
      expect(hl.imageArea!.height, 0.4);
    });
  });

  group('HighlightToStorage', () {
    test('maps all fields from domain to companion', () {
      final hl = Highlight(
        id: 'h1',
        sourceId: 'book-1',
        sourceType: SourceType.book,
        text: 'Important text',
        note: 'My note',
        cfiRange: 'epubcfi(/6/4)',
        pageNumber: 42,
        scrollOffset: 0.5,
        progress: 0.42,
        chapterTitle: 'Chapter 4',
        color: HighlightColor.blue,
        createdAt: now,
      );

      final companion = hl.toStorageModel();

      expect(companion.id, const Value('h1'));
      expect(companion.sourceId, const Value('book-1'));
      expect(companion.sourceType, const Value('book'));
      expect(companion.kind, const Value('text'));
      expect(companion.highlightText, const Value('Important text'));
      expect(companion.note, const Value('My note'));
      expect(companion.cfiRange, const Value('epubcfi(/6/4)'));
      expect(companion.pageNumber, const Value(42));
      expect(companion.scrollOffset, const Value(0.5));
      expect(companion.progress, const Value(0.42));
      expect(companion.chapterTitle, const Value('Chapter 4'));
      expect(companion.color, const Value('blue'));
      expect(companion.createdAt, Value(now.toIso8601String()));
    });

    test('round-trips through domain and back', () {
      final original = Highlight(
        id: 'h1',
        sourceId: 'book-1',
        sourceType: SourceType.book,
        text: 'Text',
        createdAt: now,
      );

      final companion = original.toStorageModel();
      final row = HighlightsTableData(
        id: companion.id.value,
        sourceId: companion.sourceId.value,
        sourceType: companion.sourceType.value,
        kind: companion.kind.value,
        highlightText: companion.highlightText.value,
        note: companion.note.value,
        cfiRange: companion.cfiRange.value,
        pageNumber: companion.pageNumber.value,
        scrollOffset: companion.scrollOffset.value,
        progress: companion.progress.value,
        chapterTitle: companion.chapterTitle.value,
        color: companion.color.value,
        createdAt: companion.createdAt.value,
      );
      final restored = row.toDomainModel();

      expect(restored, equals(original));
    });
  });
}
