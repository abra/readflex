import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_feature/src/library_source_semantics.dart';

void main() {
  test('builds readable semantics value for a new book', () {
    final source = LibrarySource.fromBook(
      Book(
        id: 'book-1',
        title: 'Flutter in Action',
        author: 'Eric Windmill',
        filePath: '/books/flutter.epub',
        format: BookFormat.epub,
        addedAt: DateTime(2026),
      ),
    );

    expect(librarySourceSemanticsLabel(source), 'Flutter in Action');
    expect(
      librarySourceSemanticsValue(source),
      'Book, Eric Windmill, EPUB, New',
    );
  });

  test('builds progress semantics after first open even at zero percent', () {
    final source = LibrarySource.fromBook(
      Book(
        id: 'book-1',
        title: 'Flutter in Action',
        filePath: '/books/flutter.epub',
        format: BookFormat.epub,
        addedAt: DateTime(2026),
        lastOpenedAt: DateTime(2026, 1, 2),
      ),
    );

    expect(librarySourceSemanticsValue(source), 'Book, EPUB, 0 percent read');
  });

  test('builds concise semantics for finished articles', () {
    final source = LibrarySource.fromArticle(
      Article(
        id: 'article-1',
        title: 'Saved Article',
        url: 'https://example.com/article',
        siteName: 'Example',
        contentPath: '/articles/article-1/article.json',
        addedAt: DateTime(2026),
        isFinished: true,
      ),
    );

    expect(librarySourceSemanticsValue(source), 'Article, Example, Finished');
  });

  test('uses selection mode to describe tap behavior', () {
    expect(
      librarySourceTapHint(isSelectionMode: false, isSelected: false),
      'Open reader',
    );
    expect(
      librarySourceTapHint(isSelectionMode: true, isSelected: false),
      'Select source',
    );
    expect(
      librarySourceTapHint(isSelectionMode: true, isSelected: true),
      'Deselect source',
    );
    expect(librarySourceLongPressHint(isSelectionMode: false), 'Select source');
    expect(librarySourceLongPressHint(isSelectionMode: true), isNull);
  });
}
