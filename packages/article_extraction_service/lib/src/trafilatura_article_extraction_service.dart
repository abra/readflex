import 'dart:async';
import 'dart:convert';

import 'package:domain_models/domain_models.dart';
import 'package:http/http.dart' as http;

import 'article_extraction_service.dart';

class TrafilaturaArticleExtractionService implements ArticleExtractionService {
  TrafilaturaArticleExtractionService({
    required Uri baseUri,
    http.Client? httpClient,
    String? apiKey,
    Duration timeout = const Duration(seconds: 45),
    int maxDownloadBytes = defaultMaxDownloadBytes,
  }) : _baseUri = baseUri,
       _httpClient = httpClient ?? http.Client(),
       _ownsClient = httpClient == null,
       _apiKey = apiKey,
       _timeout = timeout,
       _maxDownloadBytes = maxDownloadBytes;

  static const defaultMaxDownloadBytes = 8 * 1024 * 1024;

  final Uri _baseUri;
  final http.Client _httpClient;
  final bool _ownsClient;
  final String? _apiKey;
  final Duration _timeout;
  final int _maxDownloadBytes;

  @override
  Future<ExtractedArticle> extract(String url) async {
    _validateArticleUrl(url);

    try {
      return await _extractFromServer(url);
    } on ArticleExtractionException catch (e) {
      if (!_shouldFallbackToClientHtml(e)) rethrow;
    }

    final article = await _downloadArticle(url);
    return _extractFromDownloadedHtml(article);
  }

  Future<ExtractedArticle> _extractFromDownloadedHtml(
    _DownloadedArticleDocument article,
  ) async {
    final uri = _baseUri.resolve('/v1/extract-html');
    try {
      final response = await _postExtractHtml(
        uri: uri,
        article: article,
        favorPrecision: true,
        favorRecall: false,
      );
      if (_shouldRetryWithRecall(response)) {
        final retryResponse = await _postExtractHtml(
          uri: uri,
          article: article,
          favorPrecision: false,
          favorRecall: true,
        );
        return _decodeArticleResponse(retryResponse, article);
      }
      return _decodeArticleResponse(response, article);
    } on TimeoutException {
      throw const ArticleExtractionException(
        'Article cleaner request timed out',
      );
    } on http.ClientException {
      throw const ArticleExtractionException(
        'Article cleaner service is unavailable',
      );
    }
  }

  Future<ExtractedArticle> _extractFromServer(String url) async {
    final uri = _baseUri.resolve('/v1/extract');
    final article = _DownloadedArticleDocument(
      requestedUrl: url,
      resolvedUrl: url,
      contentType: null,
      bodyBytes: const [],
      metadata: const _ArticleHtmlMetadata(),
    );
    try {
      final response = await _postExtractUrl(
        uri: uri,
        url: url,
        favorPrecision: true,
        favorRecall: false,
      );
      if (_shouldRetryWithRecall(response)) {
        final retryResponse = await _postExtractUrl(
          uri: uri,
          url: url,
          favorPrecision: false,
          favorRecall: true,
        );
        return _decodeArticleResponse(retryResponse, article);
      }
      return _decodeArticleResponse(response, article);
    } on TimeoutException {
      throw const ArticleExtractionException(
        'Article cleaner request timed out',
      );
    } on http.ClientException {
      throw const ArticleExtractionException(
        'Article cleaner service is unavailable',
      );
    }
  }

  Future<_DownloadedArticleDocument> _downloadArticle(String url) async {
    final uri = _validateArticleUrl(url);

    try {
      final request = http.Request('GET', uri)
        ..headers.addAll(_downloadHeaders());

      final response = await _httpClient.send(request).timeout(_timeout);
      final statusCode = response.statusCode;
      if (statusCode < 200 || statusCode >= 300) {
        throw ArticleExtractionException(
          'Article URL returned HTTP status $statusCode',
          statusCode: statusCode,
        );
      }

      final bytes = <int>[];
      await for (final chunk in response.stream.timeout(_timeout)) {
        bytes.addAll(chunk);
        if (bytes.length > _maxDownloadBytes) {
          throw const ArticleExtractionException(
            'Article is too large to import',
            statusCode: 413,
          );
        }
      }

      return _DownloadedArticleDocument(
        requestedUrl: url,
        resolvedUrl: response.request?.url.toString() ?? url,
        contentType: response.headers['content-type'],
        bodyBytes: bytes,
        metadata: _articleHtmlMetadataFromBytes(bytes),
      );
    } on ArticleExtractionException {
      rethrow;
    } on TimeoutException {
      throw const ArticleExtractionException('Article URL download timed out');
    } on http.ClientException {
      throw const ArticleExtractionException('Could not download article URL');
    }
  }

  Future<http.Response> _postExtractHtml({
    required Uri uri,
    required _DownloadedArticleDocument article,
    required bool favorPrecision,
    required bool favorRecall,
  }) {
    return _httpClient
        .post(
          uri,
          headers: _cleanerHeaders(_apiKey),
          body: jsonEncode({
            'url': article.requestedUrl,
            'resolved_url': article.resolvedUrl,
            'html_base64': base64Encode(article.bodyBytes),
            'content_type': article.contentType,
            'body_format': 'blocks',
            'include_comments': false,
            'include_tables': true,
            'include_images': true,
            'include_links': false,
            'target_language': null,
            'fast': false,
            'favor_precision': favorPrecision,
            'favor_recall': favorRecall,
          }),
        )
        .timeout(_timeout);
  }

  Future<http.Response> _postExtractUrl({
    required Uri uri,
    required String url,
    required bool favorPrecision,
    required bool favorRecall,
  }) {
    return _httpClient
        .post(
          uri,
          headers: _cleanerHeaders(_apiKey),
          body: jsonEncode({
            'url': url,
            'body_format': 'blocks',
            'include_comments': false,
            'include_tables': true,
            'include_images': true,
            'include_links': false,
            'target_language': null,
            'fast': false,
            'favor_precision': favorPrecision,
            'favor_recall': favorRecall,
          }),
        )
        .timeout(_timeout);
  }

  ExtractedArticle _decodeArticleResponse(
    http.Response response,
    _DownloadedArticleDocument article,
  ) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = _errorPayloadFor(response);
      throw ArticleExtractionException(
        error.message,
        statusCode: response.statusCode,
        errorCode: error.code,
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw const ArticleExtractionException('Invalid article response');
    }
    final recovered = _withRecoveredImageBlocks(decoded, article);
    return _articleFromJson(_withClientMetadata(recovered, article.metadata));
  }

  bool _shouldRetryWithRecall(http.Response response) {
    if (response.statusCode != 422) return false;
    final error = _errorPayloadFor(response);
    return error.code == 'extract_failed' ||
        error.message.toLowerCase().contains('could not extract');
  }

  bool _shouldFallbackToClientHtml(ArticleExtractionException error) {
    final code = error.errorCode;
    if (code != null && code.isNotEmpty) {
      return _clientHtmlFallbackErrorCodes.contains(code);
    }

    final message = error.message.toLowerCase();
    return switch (error.statusCode) {
      422 => message.contains('could not extract'),
      502 || 508 => true,
      _ => false,
    };
  }

  @override
  void dispose() {
    if (_ownsClient) _httpClient.close();
  }
}

const _clientHtmlFallbackErrorCodes = {
  'fetch_failed',
  'extract_failed',
  'unsafe_redirect',
};

Uri _validateArticleUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null ||
      !(uri.scheme == 'http' || uri.scheme == 'https') ||
      !uri.hasAuthority) {
    throw const ArticleExtractionException('Enter a valid article URL');
  }
  return uri;
}

Map<String, String> _cleanerHeaders(String? apiKey) {
  final headers = {
    'content-type': 'application/json',
    'accept': 'application/json',
    // Ignored by normal servers; prevents ngrok free tunnels from returning
    // an HTML browser-warning page to API clients.
    'ngrok-skip-browser-warning': 'true',
  };
  if (apiKey != null && apiKey.isNotEmpty) {
    headers['X-API-Key'] = apiKey;
  }
  return headers;
}

Map<String, String> _downloadHeaders() {
  return {
    'accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'accept-language': 'en-US,en;q=0.9',
    // Many publishers serve bot interstitials or stripped fallback markup to
    // non-browser user agents. Trafilatura needs the same readable HTML a user
    // would see in a normal mobile browser.
    'user-agent':
        'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/126.0 Mobile Safari/537.36',
  };
}

/// Client-downloaded HTML document plus metadata recovered before extraction.
class _DownloadedArticleDocument {
  const _DownloadedArticleDocument({
    required this.requestedUrl,
    required this.resolvedUrl,
    required this.contentType,
    required this.bodyBytes,
    required this.metadata,
  });

  final String requestedUrl;
  final String resolvedUrl;
  final String? contentType;
  final List<int> bodyBytes;
  final _ArticleHtmlMetadata metadata;
}

/// Language and direction hints read from the original HTML.
class _ArticleHtmlMetadata {
  const _ArticleHtmlMetadata({this.language, this.textDirection});

  final String? language;
  final ArticleTextDirection? textDirection;
}

Map<String, dynamic> _withClientMetadata(
  Map<String, dynamic> json,
  _ArticleHtmlMetadata metadata,
) {
  final language =
      normalizeArticleLanguage(_string(json['language'])) ?? metadata.language;
  final textDirection =
      ArticleTextDirection.fromString(_string(json['text_direction'])) ??
      metadata.textDirection ??
      articleTextDirectionForLanguage(language);

  if (language == null && textDirection == null) return json;
  final normalizedJson = Map<String, dynamic>.from(json);
  if (language != null) normalizedJson['language'] = language;
  if (textDirection != null) {
    normalizedJson['text_direction'] = textDirection.value;
  }
  return normalizedJson;
}

_ArticleHtmlMetadata _articleHtmlMetadataFromBytes(List<int> bodyBytes) {
  if (bodyBytes.isEmpty) return const _ArticleHtmlMetadata();

  final html = utf8.decode(bodyBytes, allowMalformed: true);
  final htmlTag = _firstOpeningTag(html, 'html');
  final bodyTag = _firstOpeningTag(html, 'body');
  final articleTag = _firstOpeningTag(html, 'article');

  final language =
      normalizeArticleLanguage(_htmlAttr(htmlTag, 'lang')) ??
      normalizeArticleLanguage(_htmlAttr(htmlTag, 'xml:lang')) ??
      normalizeArticleLanguage(_htmlAttr(bodyTag, 'lang')) ??
      normalizeArticleLanguage(_htmlAttr(articleTag, 'lang')) ??
      _metaLanguage(html) ??
      _alternateHrefLanguage(html);
  final textDirection =
      ArticleTextDirection.fromString(_htmlAttr(htmlTag, 'dir')) ??
      ArticleTextDirection.fromString(_htmlAttr(bodyTag, 'dir')) ??
      ArticleTextDirection.fromString(_htmlAttr(articleTag, 'dir')) ??
      articleTextDirectionForLanguage(language);

  return _ArticleHtmlMetadata(
    language: language,
    textDirection: textDirection,
  );
}

String? _firstOpeningTag(String html, String tagName) {
  return RegExp(
    '<\\s*${RegExp.escape(tagName)}\\b[^>]*>',
    caseSensitive: false,
  ).firstMatch(html)?.group(0);
}

String? _htmlAttr(String? tag, String name) {
  if (tag == null) return null;
  final match = RegExp(
    '(?:^|\\s)${RegExp.escape(name)}\\s*=\\s*(?:"([^"]*)"|\\\'([^\\\']*)\\\'|([^\\s>]+))',
    caseSensitive: false,
  ).firstMatch(tag);
  final value = match?.group(1) ?? match?.group(2) ?? match?.group(3);
  final decoded = value == null ? null : _decodeHtmlText(value).trim();
  return decoded == null || decoded.isEmpty ? null : decoded;
}

String? _metaLanguage(String html) {
  for (final match in RegExp(
    r'<meta\b[^>]*>',
    caseSensitive: false,
  ).allMatches(html)) {
    final tag = match.group(0);
    final key =
        (_htmlAttr(tag, 'name') ??
                _htmlAttr(tag, 'property') ??
                _htmlAttr(tag, 'http-equiv'))
            ?.trim()
            .toLowerCase();
    if (key == null) continue;
    if (key != 'language' &&
        key != 'og:locale' &&
        key != 'content-language' &&
        key != 'dc.language') {
      continue;
    }
    final language = normalizeArticleLanguage(_htmlAttr(tag, 'content'));
    if (language != null) return language;
  }
  return null;
}

String? _alternateHrefLanguage(String html) {
  for (final match in RegExp(
    r'<link\b[^>]*>',
    caseSensitive: false,
  ).allMatches(html)) {
    final tag = match.group(0);
    final rel = _htmlAttr(tag, 'rel')?.toLowerCase();
    if (rel == null || !rel.split(RegExp(r'\s+')).contains('alternate')) {
      continue;
    }
    final language = normalizeArticleLanguage(_htmlAttr(tag, 'hreflang'));
    if (language != null) return language;
  }
  return null;
}

Map<String, dynamic> _withRecoveredImageBlocks(
  Map<String, dynamic> json,
  _DownloadedArticleDocument article,
) {
  // Some cleaner responses keep image captions but drop image blocks. JSON-LD
  // often still contains `[Image: caption url]` markers, so we rebuild those
  // blocks only when the recovered captions line up with the body paragraphs.
  final body = json['body'];
  if (body is! List || _hasImageBlocks(body)) return json;

  final markers = _jsonLdImageMarkers(article.bodyBytes);
  if (markers.isEmpty) return json;

  final updatedBody = _replaceCaptionParagraphsWithImages(body, markers);
  if (updatedBody == null) return json;

  return {...json, 'body': updatedBody};
}

bool _hasImageBlocks(List<dynamic> body) {
  return body.any((block) => block is Map && block['type'] == 'image');
}

List<Object?>? _replaceCaptionParagraphsWithImages(
  List<dynamic> body,
  List<_StructuredImageMarker> markers,
) {
  final updated = <Object?>[];
  var markerIndex = 0;
  var inserted = false;

  for (final block in body) {
    final marker = markerIndex < markers.length ? markers[markerIndex] : null;
    if (marker != null &&
        block is Map &&
        block['type'] == 'paragraph' &&
        _matchesImageCaption(_string(block['text']) ?? '', marker.caption)) {
      updated.add({
        'type': 'image',
        'src': marker.src,
        'alt': marker.caption,
        'title': _string(block['text'])?.trim(),
      });
      markerIndex += 1;
      inserted = true;
      continue;
    }

    updated.add(block);
  }

  return inserted ? updated : null;
}

bool _matchesImageCaption(String paragraph, String caption) {
  final normalizedParagraph = _normalizeCaption(paragraph);
  final normalizedCaption = _normalizeCaption(caption);
  if (normalizedParagraph.isEmpty || normalizedCaption.isEmpty) return false;
  return normalizedParagraph.startsWith(normalizedCaption) ||
      normalizedCaption.startsWith(normalizedParagraph);
}

String _normalizeCaption(String value) {
  return value
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAllMapped(RegExp(r'\s+([.,;:!?])'), (match) => match.group(1)!)
      .trim()
      .toLowerCase();
}

List<_StructuredImageMarker> _jsonLdImageMarkers(List<int> bodyBytes) {
  final html = utf8.decode(bodyBytes, allowMalformed: true);
  final markers = <_StructuredImageMarker>[];

  for (final match in _jsonLdScriptRegex.allMatches(html)) {
    final script = _decodeHtmlText(match.group(1) ?? '').trim();
    if (script.isEmpty) continue;

    try {
      _collectJsonLdImageMarkers(jsonDecode(script), markers);
    } catch (_) {
      continue;
    }
  }

  return markers;
}

void _collectJsonLdImageMarkers(
  Object? value,
  List<_StructuredImageMarker> markers,
) {
  switch (value) {
    case Map<String, dynamic> map:
      final articleBody = _string(map['articleBody']);
      if (articleBody != null) {
        markers.addAll(_imageMarkersFromArticleBody(articleBody));
      }
      for (final child in map.values) {
        _collectJsonLdImageMarkers(child, markers);
      }
    case Map map:
      for (final child in map.values) {
        _collectJsonLdImageMarkers(child, markers);
      }
    case List list:
      for (final child in list) {
        _collectJsonLdImageMarkers(child, markers);
      }
  }
}

List<_StructuredImageMarker> _imageMarkersFromArticleBody(String articleBody) {
  return [
        for (final match in _articleBodyImageMarkerRegex.allMatches(
          articleBody,
        ))
          _StructuredImageMarker(
            caption: _decodeHtmlText(match.group(1) ?? '').trim(),
            src: _decodeHtmlText(match.group(2) ?? '').trim(),
          ),
      ]
      .where((marker) => marker.caption.isNotEmpty && marker.src.isNotEmpty)
      .toList(growable: false);
}

final _jsonLdScriptRegex = RegExp(
  r'''<script\b[^>]*type=["'][^"']*application/ld\+json[^"']*["'][^>]*>([\s\S]*?)</script>''',
  caseSensitive: false,
);

final _articleBodyImageMarkerRegex = RegExp(
  r'\[Image:\s*(.*?)(https?:\/\/[^\]]+)\]',
  caseSensitive: false,
);

/// Image marker recovered from JSON-LD `articleBody` text.
class _StructuredImageMarker {
  const _StructuredImageMarker({required this.caption, required this.src});

  final String caption;
  final String src;
}

ExtractedArticle _articleFromJson(Map<String, dynamic> json) {
  final requestedUrl = _string(json['requested_url']) ?? '';
  final title = _string(json['title'])?.trim();
  final body = json['body'];
  final blocks = body is List
      ? body.map(ArticleBlock.fromJson).toList(growable: false)
      : const <ArticleBlock>[];
  final plainText = _string(json['plain_text']) ?? _fallbackPlainText(blocks);
  final language = normalizeArticleLanguage(_string(json['language']));
  final textDirection =
      ArticleTextDirection.fromString(_string(json['text_direction'])) ??
      articleTextDirectionForLanguage(language) ??
      inferArticleTextDirectionFromText(plainText);
  final normalizedJson = Map<String, dynamic>.from(json);
  if (language != null) normalizedJson['language'] = language;
  if (textDirection != null) {
    normalizedJson['text_direction'] = textDirection.value;
  }
  final fallbackTitle = blocks
      .whereType<ArticleHeadingBlock>()
      .map((block) => block.text.trim())
      .firstWhere((text) => text.isNotEmpty, orElse: () => 'Untitled article');

  return ExtractedArticle(
    requestedUrl: requestedUrl,
    resolvedUrl: _string(json['resolved_url']),
    canonicalUrl: _string(json['canonical_url']),
    title: title == null || title.isEmpty ? fallbackTitle : title,
    author: _string(json['author']),
    date: _string(json['date']),
    site: _string(json['site']),
    hostname: _string(json['hostname']),
    description: _string(json['description']),
    imageUrl: _string(json['image']),
    language: language,
    textDirection: textDirection,
    categories: _stringList(json['categories']),
    tags: _stringList(json['tags']),
    license: _string(json['license']),
    fingerprint: _string(json['fingerprint']),
    blocks: blocks,
    plainText: plainText,
    rawJson: jsonEncode(normalizedJson),
  );
}

_CleanerErrorPayload _errorPayloadFor(http.Response response) {
  try {
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is Map) {
      final detail =
          decoded['detail'] ?? decoded['message'] ?? decoded['error'];
      if (detail is Map) {
        final message = _string(detail['message']);
        return _CleanerErrorPayload(
          code: _string(detail['code']),
          message: message == null || message.trim().isEmpty
              ? _defaultErrorMessageFor(response.statusCode)
              : message,
        );
      }
      if (detail is String && detail.trim().isNotEmpty) {
        return _CleanerErrorPayload(message: detail);
      }
      if (detail is List) {
        final messages = detail
            .whereType<Map>()
            .map(_validationMessage)
            .where((message) => message.isNotEmpty)
            .toList(growable: false);
        if (messages.isNotEmpty) {
          return _CleanerErrorPayload(message: messages.join('\n'));
        }
      }
    }
  } catch (_) {}

  return _CleanerErrorPayload(
    message: _defaultErrorMessageFor(response.statusCode),
  );
}

String _defaultErrorMessageFor(int statusCode) {
  return switch (statusCode) {
    401 || 403 => 'Article cleaner authentication failed',
    413 => 'Article is too large to import',
    422 => 'This URL cannot be extracted',
    502 => 'Article cleaner could not fetch the page',
    508 => 'Article cleaner stopped an unsafe redirect',
    _ => 'Article extraction failed',
  };
}

/// Error payload returned by recent article-cleaner backends.
class _CleanerErrorPayload {
  const _CleanerErrorPayload({this.code, required this.message});

  final String? code;
  final String message;
}

String _validationMessage(Map<dynamic, dynamic> error) {
  final msg = error['msg'];
  if (msg is! String || msg.trim().isEmpty) return '';
  final loc = error['loc'];
  if (loc is! List || loc.isEmpty) return msg;
  return '${loc.join('.')}: $msg';
}

String _fallbackPlainText(List<ArticleBlock> blocks) {
  return blocks
      .map((block) => block.fallbackText.trim())
      .where((text) => text.isNotEmpty)
      .join('\n\n');
}

String? _string(Object? value) => value is String ? value : null;

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item != null) item.toString(),
  ];
}

String _decodeHtmlText(String value) {
  return value
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&sol;', '/')
      .replaceAllMapped(_numericEntityRegex, (match) {
        final hexValue = match.group(1);
        final decimalValue = match.group(2);
        final codePoint = hexValue != null
            ? int.tryParse(hexValue, radix: 16)
            : int.tryParse(decimalValue ?? '');
        if (codePoint == null) return match.group(0) ?? '';
        return String.fromCharCode(codePoint);
      });
}

final _numericEntityRegex = RegExp(r'&#x([0-9a-fA-F]+);|&#([0-9]+);');
