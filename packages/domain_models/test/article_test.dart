import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Article derives reader HTML path next to stored content', () {
    final article = Article(
      id: 'a1',
      title: 'Article',
      url: 'https://example.com/a',
      contentPath: '/data/articles/a1/article.json',
      addedAt: DateTime(2026),
    );

    expect(article.contentHtmlPath, '/data/articles/a1/content.html');
  });

  test('LibrarySource maps article metadata for shared library surfaces', () {
    final article = Article(
      id: 'a1',
      title: 'Article',
      url: 'https://example.com/a',
      canonicalUrl: 'https://example.com/canonical-a',
      author: 'Author',
      siteName: 'Example',
      contentPath: '/data/articles/a1/article.json',
      readingProgress: 0.4,
      textLength: 4200,
      estimatedWordCount: 900,
      addedAt: DateTime(2026),
    );

    final source = LibrarySource.fromArticle(article);

    expect(source.sourceType, SourceType.article);
    expect(source.author, 'Author');
    expect(source.sourceName, 'Example');
    expect(source.originalUrl, 'https://example.com/a');
    expect(source.typeLabel, 'Article');
    expect(source.readingProgress, 0.4);
    expect(source.estimatedWordCount, 900);
    expect(source.estimatedCharacterCount, 4200);
    expect(source.supportsReview, isTrue);
  });
}
