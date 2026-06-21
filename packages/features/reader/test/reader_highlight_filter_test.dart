import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_highlight_filter.dart';
import 'package:reader/src/reader_highlight_location_label.dart';

void main() {
  final first = Highlight(
    id: 'highlight-1',
    sourceId: 'book-1',
    sourceType: SourceType.book,
    text: 'Dependency injection keeps wiring explicit.',
    note: 'Architecture note',
    cfiRange: 'epubcfi(/6/2)',
    progress: 0.42,
    chapterTitle: 'Dependency Injection',
    color: HighlightColor.yellow,
    createdAt: DateTime(2026, 5, 17),
  );
  final second = Highlight(
    id: 'highlight-2',
    sourceId: 'book-1',
    sourceType: SourceType.book,
    text: 'Factory Method overview',
    pageNumber: 42,
    color: HighlightColor.blue,
    createdAt: DateTime(2026, 5, 17, 1),
  );
  final imageArea = Highlight(
    id: 'highlight-3',
    sourceId: 'book-1',
    sourceType: SourceType.book,
    text: 'Page highlight',
    kind: HighlightKind.imageArea,
    imageArea: const HighlightImageArea(
      pageIndex: 7,
      x: 0.1,
      y: 0.2,
      width: 0.3,
      height: 0.4,
    ),
    pageNumber: 8,
    color: HighlightColor.green,
    createdAt: DateTime(2026, 5, 17, 2),
  );
  final highlights = [first, second, imageArea];

  test('returns all highlights for an empty query', () {
    expect(filterReaderHighlights(highlights, '  '), highlights);
  });

  test('matches highlight text case-insensitively', () {
    expect(filterReaderHighlights(highlights, 'factory'), [second]);
  });

  test('matches notes', () {
    expect(filterReaderHighlights(highlights, 'architecture'), [first]);
  });

  test('matches legacy page labels', () {
    expect(filterReaderHighlights(highlights, 'page 42'), [second]);
  });

  test('matches chapter titles', () {
    expect(filterReaderHighlights(highlights, 'dependency injection'), [first]);
  });

  test('matches progress labels', () {
    expect(filterReaderHighlights(highlights, '42%'), [first]);
  });

  test('matches highlight color names', () {
    expect(filterReaderHighlights(highlights, 'blue'), [second]);
  });

  test('formats current highlight location labels', () {
    expect(readerHighlightLocationLabel(first), 'Dependency Injection · 42%');
  });

  test('falls back to legacy page labels', () {
    expect(readerHighlightLocationLabel(second), 'Page 42');
  });

  test('treats text CFI and image-area highlights as navigable', () {
    expect(readerHighlightHasNavigableLocation(first), isTrue);
    expect(readerHighlightHasNavigableLocation(imageArea), isTrue);
  });

  test('does not treat legacy page-only highlights as navigable', () {
    expect(readerHighlightHasNavigableLocation(second), isFalse);
  });
}
