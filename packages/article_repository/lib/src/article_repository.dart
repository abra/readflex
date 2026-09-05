import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:domain_models/domain_models.dart';
import 'package:drift/drift.dart' show Value;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:local_storage/local_storage.dart';
import 'package:monitoring/monitoring.dart';
import 'package:path/path.dart' as p;
import 'package:remote_content_policy/remote_content_policy.dart';
import 'package:uuid/uuid.dart' show Uuid;

import 'mappers/article_to_domain.dart';
import 'mappers/article_to_storage.dart';

const _uuid = Uuid();

class ArticleRepository {
  ArticleRepository({
    required AppDatabase database,
    required Directory articlesDirectory,
    http.Client? httpClient,
    Logger? logger,
    RemoteUriPolicy? remoteUriPolicy,
    int maxArticleImages = defaultMaxArticleImages,
    int maxImageBytes = defaultMaxImageBytes,
    int maxTotalImageBytes = defaultMaxTotalImageBytes,
    Duration imageDownloadTimeout = defaultImageDownloadTimeout,
    Duration totalImageDownloadTimeout = defaultTotalImageDownloadTimeout,
    int maxImageRedirects = defaultMaxImageRedirects,
  }) : _db = database,
       _dao = database.articlesDao,
       _articlesDir = articlesDirectory,
       _httpClient =
           httpClient ??
           IOClient(
             createPublicRemoteHttpClient(
               uriPolicy: remoteUriPolicy ?? RemoteUriPolicy(),
             ),
           ),
       _ownsHttpClient = httpClient == null,
       _logger = logger,
       _remoteUriPolicy = remoteUriPolicy ?? RemoteUriPolicy(),
       _maxArticleImages = maxArticleImages,
       _maxImageBytes = maxImageBytes,
       _maxTotalImageBytes = maxTotalImageBytes,
       _imageDownloadTimeout = imageDownloadTimeout,
       _totalImageDownloadTimeout = totalImageDownloadTimeout,
       _maxImageRedirects = maxImageRedirects,
       assert(maxArticleImages > 0),
       assert(maxImageBytes > 0),
       assert(maxTotalImageBytes > 0),
       assert(imageDownloadTimeout > Duration.zero),
       assert(totalImageDownloadTimeout > Duration.zero),
       assert(maxImageRedirects >= 0);

  static const defaultMaxArticleImages = 64;
  static const defaultMaxImageBytes = 10 * 1024 * 1024;
  static const defaultMaxTotalImageBytes = 48 * 1024 * 1024;
  static const defaultImageDownloadTimeout = Duration(seconds: 30);
  static const defaultTotalImageDownloadTimeout = Duration(seconds: 90);
  static const defaultMaxImageRedirects = 5;

  final AppDatabase _db;
  final ArticlesDao _dao;
  final Directory _articlesDir;
  final http.Client _httpClient;
  final bool _ownsHttpClient;
  final Logger? _logger;
  final RemoteUriPolicy _remoteUriPolicy;
  final int _maxArticleImages;
  final int _maxImageBytes;
  final int _maxTotalImageBytes;
  final Duration _imageDownloadTimeout;
  final Duration _totalImageDownloadTimeout;
  final int _maxImageRedirects;

  void dispose() {
    if (_ownsHttpClient) _httpClient.close();
  }

  Future<List<Article>> getArticles({int? limit, int? offset}) async {
    try {
      final rows = await _dao.allArticles(limit: limit, offset: offset);
      return rows
          .map((row) => row.toDomainModel(articlesDir: _articlesDir))
          .toList(growable: false);
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  Future<Article?> getArticleById(String id) async {
    try {
      final row = await _dao.articleById(id);
      return row?.toDomainModel(articlesDir: _articlesDir);
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  Future<Article> addExtractedArticle(ExtractedArticle extracted) async {
    final id = _uuid.v4();
    final articleDir = Directory(p.join(_articlesDir.path, id));
    try {
      final now = DateTime.now();
      await articleDir.create(recursive: true);

      final contentFile = File(p.join(articleDir.path, 'article.json'));
      await contentFile.writeAsString(extracted.rawJson, flush: true);

      final baseUri = _articleBaseUri(extracted);
      final blocks = _withoutDuplicateTitleHeading(
        extracted.blocks,
        extracted.title,
      );
      final localImages = await _downloadArticleImages(
        blocks: blocks,
        articleDir: articleDir,
        baseUri: baseUri,
      );
      await File(
        p.join(articleDir.path, 'content.html'),
      ).writeAsString(_htmlForBlocks(blocks, localImages), flush: true);

      String? coverFilename;
      if (extracted.imageUrl case final url? when url.isNotEmpty) {
        final uri = _resolveRemoteUri(url, baseUri);
        if (uri != null) {
          coverFilename = await _tryDownloadCover(articleDir, uri);
        }
      }

      final language = normalizeArticleLanguage(extracted.language);

      final article = Article(
        id: id,
        title: extracted.title,
        url: extracted.requestedUrl,
        resolvedUrl: extracted.resolvedUrl,
        canonicalUrl: extracted.canonicalUrl,
        author: extracted.author,
        siteName: extracted.site,
        hostname: extracted.hostname,
        description: extracted.description,
        imageUrl: extracted.imageUrl,
        coverImagePath: coverFilename == null
            ? null
            : p.join(articleDir.path, coverFilename),
        language: language,
        contentPath: contentFile.path,
        plainText: extracted.plainText,
        textLength: extracted.plainText.length,
        estimatedWordCount: extracted.wordCount,
        addedAt: now,
      );
      await _dao.insertArticle(article.toStorageModel());
      return article;
    } catch (e, st) {
      await _tryDeleteDirectory(articleDir);
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  Future<Article> updateArticle(Article article) async {
    try {
      await _dao.updateArticle(article.toStorageModel());
      return article;
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  /// Position writes never replace concurrently edited article metadata.
  Future<void> updateReadingPosition(
    String id, {
    required String? cfi,
    required double progress,
  }) async {
    try {
      await _dao.updateArticle(
        ArticlesTableCompanion(
          id: Value(id),
          currentCfi: Value(cfi),
          readingProgress: Value(progress),
        ),
      );
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  Future<void> markOpened(String id, DateTime openedAt) async {
    try {
      await _dao.updateArticle(
        ArticlesTableCompanion(
          id: Value(id),
          lastOpenedAt: Value(openedAt.toIso8601String()),
        ),
      );
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  Future<void> deleteArticle(String id) async {
    try {
      await _db.transaction(() async {
        await _db.reviewItemsDao.deleteItemsBySource(id);
        await _db.highlightsDao.deleteHighlightsBySource(id);
        await _db.flashcardsDao.deleteFlashcardsByDeck(id);
        await _db.dictionaryDao.deleteEntriesBySource(id);
        await _db.customStatement(
          'DELETE FROM bookmarks_table WHERE source_id = ?',
          [id],
        );
        await _dao.deleteArticle(id);
      });
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }

    await _tryDeleteDirectory(Directory(p.join(_articlesDir.path, id)));
  }

  Future<void> _tryDeleteDirectory(Directory directory) async {
    try {
      if (await directory.exists()) await directory.delete(recursive: true);
    } catch (e, st) {
      _logger?.warn(
        'ArticleRepository: failed to delete ${directory.path}',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<Map<String, String>> _downloadArticleImages({
    required List<ArticleBlock> blocks,
    required Directory articleDir,
    required Uri? baseUri,
  }) async {
    final sources = <String, Uri>{};
    final uniqueUris = <String>{};
    for (final block in blocks.whereType<ArticleImageBlock>()) {
      final source = block.src;
      final uri = _resolveRemoteUri(source, baseUri);
      if (uri == null || sources.containsKey(source)) {
        continue;
      }
      final uriKey = uri.toString();
      if (!uniqueUris.contains(uriKey) &&
          uniqueUris.length >= _maxArticleImages) {
        continue;
      }
      uniqueUris.add(uriKey);
      sources[source] = uri;
    }
    if (sources.isEmpty) return const {};

    final replacements = <String, String>{};
    final downloadedByUri = <String, _DownloadedArticleImage?>{};
    final imagesDir = Directory(p.join(articleDir.path, 'images'));
    final totalDeadline = DateTime.now().add(_totalImageDownloadTimeout);
    final downloadBudget = _ImageDownloadBudget(_maxTotalImageBytes);

    for (final entry in sources.entries) {
      final now = DateTime.now();
      final remainingBytes = downloadBudget.remainingBytes;
      if (!now.isBefore(totalDeadline) || remainingBytes <= 0) break;

      final uriKey = entry.value.toString();
      _DownloadedArticleImage? image;
      if (downloadedByUri.containsKey(uriKey)) {
        image = downloadedByUri[uriKey];
      } else {
        await imagesDir.create(recursive: true);
        final imageDeadline = _earlierOf(
          totalDeadline,
          now.add(_imageDownloadTimeout),
        );
        image = await _tryDownloadImage(
          directory: imagesDir,
          uri: entry.value,
          maxBytes: math.min(_maxImageBytes, remainingBytes),
          deadline: imageDeadline,
          downloadBudget: downloadBudget,
        );
        downloadedByUri[uriKey] = image;
      }
      if (image == null) continue;
      replacements[entry.key] = 'images/${image.filename}';
    }
    return replacements;
  }

  Future<_DownloadedArticleImage?> _tryDownloadImage({
    required Directory directory,
    required Uri uri,
    required int maxBytes,
    required DateTime deadline,
    _ImageDownloadBudget? downloadBudget,
    String Function(Uri uri, String extension)? filenameFor,
  }) async {
    try {
      final remote = await _openImageResponse(uri, deadline);
      if (remote == null) return null;
      final declaredLength = int.tryParse(
        remote.response.headers['content-length'] ?? '',
      );
      if (declaredLength != null && declaredLength > maxBytes) {
        await _cancelResponse(remote.response);
        return null;
      }
      final contentType = _contentType(
        remote.response.headers['content-type'],
      );
      if (contentType != null &&
          !_allowedImageContentTypes.contains(contentType)) {
        await _cancelResponse(remote.response);
        return null;
      }

      final temporaryFile = File(
        p.join(directory.path, '.${_uuid.v4()}.download'),
      );
      IOSink? output;
      try {
        output = temporaryFile.openWrite();
        final prefix = <int>[];
        var byteCount = 0;
        final chunks = StreamIterator(remote.response.stream);
        try {
          while (await chunks.moveNext().timeout(
            _remainingUntil(deadline),
          )) {
            final chunk = chunks.current;
            if (downloadBudget != null &&
                !downloadBudget.consume(chunk.length)) {
              throw const _ImageDownloadLimitReached();
            }
            byteCount += chunk.length;
            if (byteCount > maxBytes) {
              throw const _ImageDownloadLimitReached();
            }
            if (prefix.length < _imageSignatureLength) {
              prefix.addAll(
                chunk.take(_imageSignatureLength - prefix.length),
              );
            }
            output.add(chunk);
          }
        } finally {
          await chunks.cancel();
        }
        await output.flush();
        await output.close();
        output = null;

        if (byteCount == 0) return null;
        final extension = _validatedImageExtension(
          prefix,
          contentType,
        );
        if (extension == null) return null;

        final filename =
            filenameFor?.call(remote.uri, extension) ??
            '${sha256.convert(utf8.encode(remote.uri.toString()))}$extension';
        await temporaryFile.rename(p.join(directory.path, filename));
        return _DownloadedArticleImage(filename: filename);
      } finally {
        if (output != null) {
          try {
            await output.close();
          } catch (_) {
            // Best-effort cleanup; the original download error is primary.
          }
        }
        if (await temporaryFile.exists()) await temporaryFile.delete();
      }
    } catch (e, st) {
      _logger?.debug(
        'ArticleRepository: image download failed ($uri)',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  Future<String?> _tryDownloadCover(Directory articleDir, Uri uri) async {
    final image = await _tryDownloadImage(
      directory: articleDir,
      uri: uri,
      maxBytes: _maxImageBytes,
      deadline: DateTime.now().add(_imageDownloadTimeout),
      filenameFor: (_, extension) => 'cover$extension',
    );
    return image?.filename;
  }

  Future<_ValidatedImageResponse?> _openImageResponse(
    Uri initialUri,
    DateTime deadline,
  ) async {
    var currentUri = initialUri;
    var redirectCount = 0;

    while (true) {
      await _remoteUriPolicy
          .validate(currentUri)
          .timeout(
            _remainingUntil(deadline),
          );
      final request = http.Request('GET', currentUri)
        ..followRedirects = false
        ..maxRedirects = 0
        ..headers['accept'] =
            'image/avif,image/webp,image/png,image/jpeg,image/gif;q=0.9,*/*;q=0.1';
      final response = await _httpClient
          .send(request)
          .timeout(
            _remainingUntil(deadline),
          );

      if (_isRedirectStatus(response.statusCode)) {
        await _cancelResponse(response);
        final location = response.headers['location'];
        if (location == null ||
            location.trim().isEmpty ||
            redirectCount >= _maxImageRedirects) {
          return null;
        }
        currentUri = currentUri.resolve(location);
        redirectCount++;
        continue;
      }

      if (response.statusCode != 200) {
        await _cancelResponse(response);
        return null;
      }
      return _ValidatedImageResponse(uri: currentUri, response: response);
    }
  }
}

class _DownloadedArticleImage {
  const _DownloadedArticleImage({required this.filename});

  final String filename;
}

class _ValidatedImageResponse {
  const _ValidatedImageResponse({required this.uri, required this.response});

  final Uri uri;
  final http.StreamedResponse response;
}

class _ImageDownloadLimitReached implements Exception {
  const _ImageDownloadLimitReached();
}

class _ImageDownloadBudget {
  _ImageDownloadBudget(this.remainingBytes);

  int remainingBytes;

  bool consume(int byteCount) {
    if (byteCount > remainingBytes) {
      remainingBytes = 0;
      return false;
    }
    remainingBytes -= byteCount;
    return true;
  }
}

String _htmlForBlocks(
  List<ArticleBlock> blocks,
  Map<String, String> localImages,
) {
  final buffer = StringBuffer();
  var headingIndex = 0;
  var blockIndex = 0;
  for (final block in blocks) {
    final blockId = 'block-${blockIndex++}';
    switch (block) {
      case ArticleParagraphBlock(:final text):
        if (text.trim().isNotEmpty) {
          buffer.writeln(
            '<p id="${_attr(blockId)}" data-rf-block-id="${_attr(blockId)}">'
            '${_sentenceSpans(text, blockId)}</p>',
          );
        }
      case ArticleHeadingBlock(:final level, :final text):
        final title = text.trim();
        if (title.isNotEmpty) {
          final id = 'section-${++headingIndex}';
          final safeLevel = _safeHeadingLevel(level);
          buffer.writeln(
            '<h$safeLevel id="${_attr(id)}">${_text(title)}</h$safeLevel>',
          );
        }
      case ArticleImageBlock(:final src, :final alt, :final title):
        if (src.trim().isNotEmpty) {
          // Rejected or over-budget images must not trigger an unguarded WebView retry.
          final localSource = localImages[src];
          final sourceAttribute = localSource == null
              ? ''
              : ' src="${_attr(localSource)}"';
          buffer.writeln(
            '<figure id="${_attr(blockId)}" data-rf-block-id="${_attr(blockId)}">'
            '<img$sourceAttribute alt="${_attr(alt ?? '')}"/>'
            '${title == null ? '' : '<figcaption>${_text(title)}</figcaption>'}'
            '</figure>',
          );
        }
      case ArticleListBlock(:final items):
        if (items.isNotEmpty) {
          buffer.writeln('<ul>');
          for (final item in items) {
            final itemBlockId = 'block-${blockIndex++}';
            buffer.writeln(
              '<li id="${_attr(itemBlockId)}" '
              'data-rf-block-id="${_attr(itemBlockId)}">'
              '${_sentenceSpans(item, itemBlockId)}</li>',
            );
          }
          buffer.writeln('</ul>');
        }
      case ArticleQuoteBlock(:final text):
        if (text.trim().isNotEmpty) {
          buffer.writeln(
            '<blockquote id="${_attr(blockId)}" '
            'data-rf-block-id="${_attr(blockId)}">'
            '${_sentenceSpans(text, blockId)}</blockquote>',
          );
        }
      case ArticleCodeBlock(:final text):
        if (text.trim().isNotEmpty) {
          buffer.writeln(
            '<pre id="${_attr(blockId)}" data-rf-block-id="${_attr(blockId)}">'
            '<code>${_text(text)}</code></pre>',
          );
        }
      case ArticleTableBlock(:final rows):
        if (rows.isNotEmpty) {
          buffer.writeln(
            '<div id="${_attr(blockId)}" data-rf-block-id="${_attr(blockId)}" '
            'class="rf-table-scroll"><table><tbody>',
          );
          for (final row in rows) {
            buffer.writeln('<tr>');
            for (final cell in row) {
              buffer.writeln('<td>${_text(cell)}</td>');
            }
            buffer.writeln('</tr>');
          }
          buffer.writeln('</tbody></table></div>');
        }
      case ArticleUnknownBlock(:final fallbackText):
        if (fallbackText.trim().isNotEmpty) {
          buffer.writeln(
            '<p id="${_attr(blockId)}" data-rf-block-id="${_attr(blockId)}">'
            '${_sentenceSpans(fallbackText, blockId)}</p>',
          );
        }
    }
  }
  return buffer.toString();
}

String _sentenceSpans(String text, String blockId) {
  final sentences = _sentenceSegments(text);
  if (sentences.isEmpty) return _text(text);

  final buffer = StringBuffer();
  for (var i = 0; i < sentences.length; i++) {
    buffer.write(
      '<span id="${_attr('$blockId-s$i')}" data-rf-sentence="$i">'
      '${_text(sentences[i])}</span>',
    );
  }
  return buffer.toString();
}

List<String> _sentenceSegments(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return const [];

  final matches = RegExp(
    r'''[^.!?…。！？؟]+(?:[.!?…。！？؟]+["'”’)\]]*\s*|$)''',
    unicode: true,
  ).allMatches(text);
  final sentences = [
    for (final match in matches)
      if ((match.group(0) ?? '').trim().isNotEmpty) match.group(0)!,
  ];
  return sentences.isEmpty ? [text] : sentences;
}

int _safeHeadingLevel(int level) => level.clamp(1, 6).toInt();

List<ArticleBlock> _withoutDuplicateTitleHeading(
  List<ArticleBlock> blocks,
  String title,
) {
  if (blocks.isEmpty) return blocks;

  final firstBlock = blocks.first;
  if (firstBlock is! ArticleHeadingBlock ||
      !_sameArticleTitle(firstBlock.text, title)) {
    return blocks;
  }

  return blocks.skip(1).toList(growable: false);
}

bool _sameArticleTitle(String left, String right) {
  return _normalizeTitle(left) == _normalizeTitle(right);
}

String _normalizeTitle(String value) {
  return value.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
}

Uri? _articleBaseUri(ExtractedArticle article) {
  for (final value in [
    article.resolvedUrl,
    article.canonicalUrl,
    article.requestedUrl,
  ]) {
    final uri = _resolveRemoteUri(value, null);
    if (uri != null) return uri;
  }
  return null;
}

Uri? _resolveRemoteUri(String? value, Uri? baseUri) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) return null;

  final uri = Uri.tryParse(trimmed);
  if (uri == null) return null;

  final resolved = uri.hasScheme ? uri : baseUri?.resolveUri(uri);
  if (resolved == null || !resolved.hasAuthority) return null;
  return switch (resolved.scheme) {
    'http' || 'https' => resolved,
    _ => null,
  };
}

String? _contentType(String? value) {
  if (value == null) return null;
  return value.split(';').first.trim().toLowerCase();
}

String? _validatedImageExtension(List<int> prefix, String? mime) {
  if (mime != null && !_allowedImageContentTypes.contains(mime)) return null;
  if (_startsWith(prefix, const [0xff, 0xd8, 0xff])) return '.jpg';
  if (_startsWith(prefix, const [
    0x89,
    0x50,
    0x4e,
    0x47,
    0x0d,
    0x0a,
    0x1a,
    0x0a,
  ])) {
    return '.png';
  }
  if (_startsWith(prefix, utf8.encode('GIF87a')) ||
      _startsWith(prefix, utf8.encode('GIF89a'))) {
    return '.gif';
  }
  if (prefix.length >= 12 &&
      _startsWith(prefix, utf8.encode('RIFF')) &&
      _matchesAt(prefix, 8, utf8.encode('WEBP'))) {
    return '.webp';
  }
  if (prefix.length >= 12 &&
      _matchesAt(prefix, 4, utf8.encode('ftyp')) &&
      (_matchesAt(prefix, 8, utf8.encode('avif')) ||
          _matchesAt(prefix, 8, utf8.encode('avis')))) {
    return '.avif';
  }
  return null;
}

bool _startsWith(List<int> bytes, List<int> signature) {
  return _matchesAt(bytes, 0, signature);
}

bool _matchesAt(List<int> bytes, int offset, List<int> signature) {
  if (bytes.length < offset + signature.length) return false;
  for (var index = 0; index < signature.length; index++) {
    if (bytes[offset + index] != signature[index]) return false;
  }
  return true;
}

bool _isRedirectStatus(int statusCode) {
  return statusCode == 301 ||
      statusCode == 302 ||
      statusCode == 303 ||
      statusCode == 307 ||
      statusCode == 308;
}

Future<void> _cancelResponse(http.StreamedResponse response) {
  return response.stream.listen((_) {}).cancel();
}

Duration _remainingUntil(DateTime deadline) {
  final remaining = deadline.difference(DateTime.now());
  if (remaining <= Duration.zero) {
    throw TimeoutException('Image download timed out');
  }
  return remaining;
}

DateTime _earlierOf(DateTime first, DateTime second) {
  return first.isBefore(second) ? first : second;
}

const _imageSignatureLength = 16;
const _allowedImageContentTypes = {
  'image/jpeg',
  'image/jpg',
  'image/png',
  'image/gif',
  'image/webp',
  'image/avif',
  'application/octet-stream',
  'binary/octet-stream',
};

String _text(String value) => const HtmlEscape().convert(value);

String _attr(String value) =>
    const HtmlEscape(HtmlEscapeMode.attribute).convert(value);
