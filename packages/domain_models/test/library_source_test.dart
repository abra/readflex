import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';

LibrarySource _source({
  int estimatedCharacterCount = 12000,
  double readingProgress = 0,
  bool isFinished = false,
}) => LibrarySource(
  id: 's-1',
  sourceType: SourceType.article,
  title: 'Title',
  typeLabel: 'Article',
  addedAt: DateTime(2026),
  estimatedCharacterCount: estimatedCharacterCount,
  readingProgress: readingProgress,
  isFinished: isFinished,
);

void main() {
  group('LibrarySource.readingCharactersPerMinute', () {
    test('is ~240 words per minute at 5 characters per word', () {
      expect(LibrarySource.readingCharactersPerMinute, 240 * 5);
    });
  });

  group('LibrarySource.estimatedMinutesLeft', () {
    test('is the full length for an unread source', () {
      expect(_source().estimatedMinutesLeft, 10);
    });

    test('scales with the unread fraction', () {
      expect(
        _source(readingProgress: 0.25).estimatedMinutesLeft,
        closeTo(7.5, 1e-9),
      );
      expect(
        _source(readingProgress: 0.9).estimatedMinutesLeft,
        closeTo(1, 1e-9),
      );
    });

    test('is zero at the end of an unfinished source', () {
      expect(_source(readingProgress: 1).estimatedMinutesLeft, 0);
    });

    test('clamps progress outside 0..1', () {
      expect(_source(readingProgress: -0.5).estimatedMinutesLeft, 10);
      expect(_source(readingProgress: 1.5).estimatedMinutesLeft, 0);
    });

    test('is null when the length is unknown', () {
      expect(_source(estimatedCharacterCount: 0).estimatedMinutesLeft, isNull);
      expect(
        _source(estimatedCharacterCount: -10).estimatedMinutesLeft,
        isNull,
      );
    });

    test('is null for a finished source', () {
      expect(
        _source(readingProgress: 0.4, isFinished: true).estimatedMinutesLeft,
        isNull,
      );
    });

    test('is null for books, which report no character count', () {
      final book = LibrarySource.fromBook(
        Book(
          id: 'b-1',
          title: 'Book',
          filePath: '/b.epub',
          format: BookFormat.epub,
          addedAt: DateTime(2026),
          readingProgress: 0.3,
        ),
      );
      expect(book.estimatedMinutesLeft, isNull);
    });

    test('articles use their text length', () {
      final article = LibrarySource.fromArticle(
        Article(
          id: 'a-1',
          title: 'Article',
          url: 'https://example.com',
          contentPath: '/a.json',
          addedAt: DateTime(2026),
          textLength: 6000,
          readingProgress: 0.5,
        ),
      );
      expect(article.estimatedMinutesLeft, closeTo(2.5, 1e-9));
    });
  });
}
