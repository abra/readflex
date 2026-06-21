import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_highlight_filter.dart';

void main() {
  final first = Highlight(
    id: 'highlight-1',
    sourceId: 'book-1',
    sourceType: SourceType.book,
    text: 'Dependency injection keeps wiring explicit.',
    note: 'Architecture note',
    cfiRange: 'epubcfi(/6/2)',
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
  final highlights = [first, second];

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

  test('matches highlight color names', () {
    expect(filterReaderHighlights(highlights, 'blue'), [second]);
  });
}
