import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:readability_dart/readability_dart.dart' as readability;

import 'article_html_sanitizer.dart';

/// Cleaned article content extracted from a web page, along with metadata
/// (title, byline, cover image, language). Produced by [ArticleParser.parse]
/// and consumed by the import flow / reader server.
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

/// Stage of the parse pipeline that failed. Callers map this to a
/// user-facing message — the exception [message] is kept for logs only.
enum ArticleParserFailure {
  /// URL didn't parse / had no scheme.
  invalidUrl,

  /// Network couldn't reach the host (DNS, timeout, refused connection).
  network,

  /// Host replied with a non-200 status. [ArticleParserException.statusCode]
  /// carries the code.
  httpStatus,

  /// Readability ran but couldn't extract a readable body from the page.
  noContent,
}

/// Thrown when article parsing fails.
class ArticleParserException implements Exception {
  const ArticleParserException({
    required this.reason,
    required this.message,
    this.statusCode,
  });

  final ArticleParserFailure reason;
  final String message;

  /// Populated when [reason] is [ArticleParserFailure.httpStatus].
  final int? statusCode;

  @override
  String toString() => 'ArticleParserException($reason): $message';
}

/// Contract for fetching an article URL and extracting its readable
/// content. Used by the import flow to turn an arbitrary web page into a
/// [ParsedArticle] that the reader server can serve.
abstract class ArticleParser {
  /// Fetches [url] and returns the cleaned article. Throws
  /// [ArticleParserException] with a [ArticleParserFailure] reason on any
  /// step that fails (invalid URL, network, non-200 status, empty content).
  Future<ParsedArticle> parse(String url);
}

/// Production [ArticleParser]: fetches HTML over [http.Client] and runs
/// `readability_dart` on-device to extract the main content. No backend
/// round-trip — cleaning happens entirely in the app process.
class ReadabilityArticleParser implements ArticleParser {
  ReadabilityArticleParser({
    http.Client? httpClient,
    ArticleHtmlSanitizer? sanitizer,
  }) : _httpClient = httpClient ?? http.Client(),
       _sanitizer = sanitizer ?? const ArticleHtmlSanitizer();

  final http.Client _httpClient;
  final ArticleHtmlSanitizer _sanitizer;

  static const _userAgent =
      'Mozilla/5.0 (compatible; ReadflexArticleParser/1.0)';

  static const _requestTimeout = Duration(seconds: 30);

  @override
  Future<ParsedArticle> parse(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      throw const ArticleParserException(
        reason: ArticleParserFailure.invalidUrl,
        message: 'Invalid URL',
      );
    }

    final http.Response response;
    try {
      response = await _httpClient
          .get(uri, headers: const {'User-Agent': _userAgent})
          .timeout(_requestTimeout);
    } catch (e) {
      throw ArticleParserException(
        reason: ArticleParserFailure.network,
        message: 'Network error: $e',
      );
    }

    if (response.statusCode != 200) {
      throw ArticleParserException(
        reason: ArticleParserFailure.httpStatus,
        message: 'HTTP ${response.statusCode} fetching $url',
        statusCode: response.statusCode,
      );
    }

    final html = _decodeBody(response);

    final readabilityInstance = readability.Readability(url, html);
    final article = readabilityInstance.parse();

    if (article == null || (article.content ?? '').isEmpty) {
      throw const ArticleParserException(
        reason: ArticleParserFailure.noContent,
        message: 'No readable content found',
      );
    }

    final rawHtml = article.content!;
    // Cover URL is harvested from the original markup (we just need the
    // string, never re-render the source). Sanitisation runs after, so the
    // HTML stored on disk has had `<script>` / event handlers / unsafe
    // URL schemes stripped — see [ArticleHtmlSanitizer].
    final coverImageUrl = _extractCoverImage(rawHtml);
    final cleanedHtml = _sanitizer.sanitize(rawHtml);

    return ParsedArticle(
      title: article.title ?? _hostTitle(uri),
      cleanedHtml: cleanedHtml,
      siteName: article.siteName,
      byline: article.byline,
      excerpt: article.excerpt,
      coverImageUrl: coverImageUrl,
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

/// Deterministic stub [ArticleParser] that returns a placeholder article
/// without touching the network. Used in tests and for developer
/// environments where the real parser is disabled.
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
