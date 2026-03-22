/// Result of parsing an article URL.
class ParsedArticle {
  const ParsedArticle({
    required this.title,
    required this.cleanedHtml,
    this.siteName,
    this.coverImageUrl,
    this.estimatedWordCount = 0,
  });

  final String title;
  final String cleanedHtml;
  final String? siteName;
  final String? coverImageUrl;
  final int estimatedWordCount;
}

/// Thrown when article parsing fails.
class ArticleParserException implements Exception {
  const ArticleParserException(this.message);

  final String message;

  @override
  String toString() => 'ArticleParserException: $message';
}

/// HTTP client to backend article cleaning service.
///
/// The backend receives a URL, runs Readability.js, and returns
/// cleaned article data.
abstract class ArticleParser {
  /// Parses article at [url] and returns cleaned content.
  Future<ParsedArticle> parse(String url);
}

/// Stub implementation that returns a placeholder article.
class NoopArticleParser implements ArticleParser {
  const NoopArticleParser();

  @override
  Future<ParsedArticle> parse(String url) async => ParsedArticle(
    title: 'Stub Article',
    cleanedHtml: '<p>Article content from $url</p>',
    siteName: 'stub',
    estimatedWordCount: 0,
  );
}
