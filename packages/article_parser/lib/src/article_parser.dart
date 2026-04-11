import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:readability_dart/readability_dart.dart' as readability;

/// Result of parsing an article URL.
class ParsedArticle {
  const ParsedArticle({
    required this.title,
    required this.cleanedHtml,
    this.siteName,
    this.byline,
    this.excerpt,
    this.coverImageUrl,
    this.publishedTime,
    this.lang,
    this.textLength = 0,
    this.estimatedWordCount = 0,
  });

  final String title;
  final String cleanedHtml;
  final String? siteName;
  final String? byline;
  final String? excerpt;
  final String? coverImageUrl;
  final String? publishedTime;
  final String? lang;

  /// Plain-text character count (from readability_dart's `length`).
  final int textLength;

  /// Rough estimate of word count, derived from textContent.
  final int estimatedWordCount;
}

/// Thrown when article parsing fails.
class ArticleParserException implements Exception {
  const ArticleParserException(this.message);

  final String message;

  @override
  String toString() => 'ArticleParserException: $message';
}

/// Fetches article HTML and extracts readable content on-device.
abstract class ArticleParser {
  /// Parses article at [url] and returns cleaned content.
  Future<ParsedArticle> parse(String url);
}

/// Real implementation: fetches HTML via [http.Client] and runs
/// `readability_dart` locally to extract clean content.
class ReadabilityArticleParser implements ArticleParser {
  ReadabilityArticleParser({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  static const _userAgent =
      'Mozilla/5.0 (compatible; ReadflexArticleParser/1.0)';

  @override
  Future<ParsedArticle> parse(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      throw const ArticleParserException('Invalid URL');
    }

    final http.Response response;
    try {
      response = await _httpClient.get(
        uri,
        headers: const {'User-Agent': _userAgent},
      );
    } catch (e) {
      throw ArticleParserException('Network error: $e');
    }

    if (response.statusCode != 200) {
      throw ArticleParserException(
        'HTTP ${response.statusCode} fetching $url',
      );
    }

    final html = _decodeBody(response);

    final readabilityInstance = readability.Readability(url, html);
    final article = readabilityInstance.parse();

    if (article == null || (article.content ?? '').isEmpty) {
      throw const ArticleParserException('No readable content found');
    }

    return ParsedArticle(
      title: article.title ?? _hostTitle(uri),
      cleanedHtml: article.content!,
      siteName: article.siteName,
      byline: article.byline,
      excerpt: article.excerpt,
      coverImageUrl: _extractCoverImage(article.content!),
      publishedTime: article.publishedTime,
      lang: article.lang,
      textLength: article.length,
      estimatedWordCount: _wordCount(article.textContent),
    );
  }

  /// Decodes the response body using the charset from Content-Type,
  /// falling back to UTF-8 for unknown or missing encodings.
  static String _decodeBody(http.Response response) {
    final charset = _charsetOf(response);
    if (charset == null || charset == 'utf-8' || charset == 'utf8') {
      return utf8.decode(response.bodyBytes, allowMalformed: true);
    }
    if (charset == 'iso-8859-1' ||
        charset == 'latin1' ||
        charset == 'latin-1') {
      return latin1.decode(response.bodyBytes);
    }
    // Unknown charset — fall back to UTF-8 and tolerate malformed bytes.
    return utf8.decode(response.bodyBytes, allowMalformed: true);
  }

  static String? _charsetOf(http.Response response) {
    final contentType = response.headers['content-type'];
    if (contentType == null) return null;
    final match = RegExp(
      r'charset=([^;\s]+)',
      caseSensitive: false,
    ).firstMatch(contentType);
    return match?.group(1)?.toLowerCase();
  }

  static String _hostTitle(Uri uri) =>
      uri.host.isNotEmpty ? uri.host : 'Article';

  /// Extracts the first `<img src="...">` absolute URL from the cleaned
  /// content as a cover candidate. Returns `null` if no image is present.
  static String? _extractCoverImage(String html) {
    final match = RegExp(
      r'<img[^>]+src="(https?://[^"]+)"',
      caseSensitive: false,
    ).firstMatch(html);
    return match?.group(1);
  }

  static int _wordCount(String? textContent) {
    if (textContent == null || textContent.isEmpty) return 0;
    return textContent
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .length;
  }
}

/// Stub implementation that returns a placeholder article. Used in tests
/// and anywhere a deterministic parser is needed without network access.
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
