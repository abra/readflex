import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:domain_models/domain_models.dart';
import 'package:http/http.dart' as http;
import 'package:local_storage/local_storage.dart';
import 'package:monitoring/monitoring.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart' show Uuid;

import 'epub_builder.dart';
import 'mappers/article_to_domain.dart';
import 'mappers/article_to_storage.dart';

const _uuid = Uuid();

class ArticleRepository {
  ArticleRepository({
    required AppDatabase database,
    required Directory articlesDirectory,
    http.Client? httpClient,
    Logger? logger,
    EpubBuilder epubBuilder = const EpubBuilder(),
  }) : _db = database,
       _dao = database.articlesDao,
       _articlesDir = articlesDirectory,
       _httpClient = httpClient ?? http.Client(),
       _ownsHttpClient = httpClient == null,
       _logger = logger,
       _epubBuilder = epubBuilder;

  final AppDatabase _db;
  final ArticlesDao _dao;
  final Directory _articlesDir;
  final http.Client _httpClient;
  final bool _ownsHttpClient;
  final Logger? _logger;
  final EpubBuilder _epubBuilder;

  static const _downloadTimeout = Duration(seconds: 30);

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
      final html = _htmlForBlocks(
        _withoutDuplicateTitleHeading(extracted.blocks, extracted.title),
      );
      final htmlWithLocalImages = await _downloadArticleImages(
        html: html,
        articleDir: articleDir,
        baseUri: baseUri,
      );
      await File(
        p.join(articleDir.path, 'content.html'),
      ).writeAsString(htmlWithLocalImages.html, flush: true);

      String? coverFilename;
      if (extracted.imageUrl case final url? when url.isNotEmpty) {
        final uri = _resolveRemoteUri(url, baseUri);
        if (uri != null) {
          coverFilename = await _tryDownloadCover(articleDir, uri);
        }
      }

      final language = normalizeArticleLanguage(extracted.language);
      final textDirection =
          extracted.textDirection ??
          articleTextDirectionForLanguage(language) ??
          inferArticleTextDirectionFromText(extracted.plainText);

      await _epubBuilder.build(
        id: id,
        title: extracted.title,
        author: extracted.author,
        lang: language,
        textDirection: textDirection,
        htmlBody: htmlWithLocalImages.html,
        images: htmlWithLocalImages.images,
        outputFile: File(p.join(articleDir.path, 'article.epub')),
      );

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

  Book toReaderBook(Article article) {
    return Book(
      id: article.id,
      title: article.title,
      author: article.author ?? article.siteName ?? article.hostname,
      coverImagePath: article.coverImagePath,
      format: BookFormat.epub,
      filePath: article.epubPath,
      currentCfi: article.currentCfi,
      readingProgress: article.readingProgress,
      addedAt: article.addedAt,
      lastOpenedAt: article.lastOpenedAt,
      isFinished: article.isFinished,
    );
  }

  Article updateFromReaderBook(Article article, Book readerBook) {
    return article.copyWith(
      currentCfi: readerBook.currentCfi,
      readingProgress: readerBook.readingProgress,
      lastOpenedAt: readerBook.lastOpenedAt,
      isFinished: readerBook.isFinished,
    );
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

  Future<_DownloadedArticleImages> _downloadArticleImages({
    required String html,
    required Directory articleDir,
    required Uri? baseUri,
  }) async {
    final matches = _imgSrcRegex.allMatches(html);
    final sources = <String, Uri>{};
    for (final match in matches) {
      final source = match.group(1);
      final uri = _resolveRemoteUri(source, baseUri);
      if (source != null && uri != null) sources[source] = uri;
    }
    if (sources.isEmpty) {
      return _DownloadedArticleImages(html: html, images: const []);
    }

    final replacements = <String, String>{};
    final images = <EpubImage>[];
    for (final entry in sources.entries) {
      final image = await _tryDownloadImage(entry.value);
      if (image == null) continue;
      replacements[entry.key] = 'images/${image.filename}';
      images.add(image);
    }
    if (replacements.isEmpty) {
      return _DownloadedArticleImages(html: html, images: const []);
    }

    final rewritten = html.replaceAllMapped(
      RegExp(replacements.keys.map(RegExp.escape).join('|')),
      (match) => replacements[match.group(0)] ?? match.group(0)!,
    );
    return _DownloadedArticleImages(html: rewritten, images: images);
  }

  Future<EpubImage?> _tryDownloadImage(Uri uri) async {
    try {
      final response = await _httpClient.get(uri).timeout(_downloadTimeout);
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        return null;
      }
      final mime = _contentType(response.headers['content-type']);
      final ext = _extensionFor(uri, mime);
      final filename =
          '${uri.toString().hashCode.toUnsigned(32).toRadixString(16)}$ext';
      return EpubImage(
        filename: filename,
        bytes: Uint8List.fromList(response.bodyBytes),
        mimeType: mime ?? EpubBuilder.mimeTypeFor(filename),
      );
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
    try {
      final response = await _httpClient.get(uri).timeout(_downloadTimeout);
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        return null;
      }
      final mime = _contentType(response.headers['content-type']);
      final filename = 'cover${_extensionFor(uri, mime)}';
      await File(
        p.join(articleDir.path, filename),
      ).writeAsBytes(response.bodyBytes, flush: true);
      return filename;
    } catch (e, st) {
      _logger?.debug(
        'ArticleRepository: cover download failed ($uri)',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }
}

class _DownloadedArticleImages {
  const _DownloadedArticleImages({required this.html, required this.images});

  final String html;
  final List<EpubImage> images;
}

final _imgSrcRegex = RegExp(
  r'''<img[^>]+src=["']([^"']+)["']''',
  caseSensitive: false,
);

String _htmlForBlocks(List<ArticleBlock> blocks) {
  final buffer = StringBuffer();
  for (final block in blocks) {
    switch (block) {
      case ArticleParagraphBlock(:final text):
        if (text.trim().isNotEmpty) buffer.writeln('<p>${_text(text)}</p>');
      case ArticleHeadingBlock(:final level, :final text):
        if (text.trim().isNotEmpty) {
          buffer.writeln('<h$level>${_text(text)}</h$level>');
        }
      case ArticleImageBlock(:final src, :final alt, :final title):
        if (src.trim().isNotEmpty) {
          buffer.writeln(
            '<figure><img src="${_attr(src)}" alt="${_attr(alt ?? '')}"/>'
            '${title == null ? '' : '<figcaption>${_text(title)}</figcaption>'}'
            '</figure>',
          );
        }
      case ArticleListBlock(:final items):
        if (items.isNotEmpty) {
          buffer.writeln('<ul>');
          for (final item in items) {
            buffer.writeln('<li>${_text(item)}</li>');
          }
          buffer.writeln('</ul>');
        }
      case ArticleQuoteBlock(:final text):
        if (text.trim().isNotEmpty) {
          buffer.writeln('<blockquote>${_text(text)}</blockquote>');
        }
      case ArticleCodeBlock(:final text):
        if (text.trim().isNotEmpty) {
          buffer.writeln('<pre><code>${_text(text)}</code></pre>');
        }
      case ArticleTableBlock(:final rows):
        if (rows.isNotEmpty) {
          buffer.writeln('<div class="rf-table-scroll"><table><tbody>');
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
          buffer.writeln('<p>${_text(fallbackText)}</p>');
        }
    }
  }
  return buffer.toString();
}

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
  final trimmed = _decodeHtmlAttribute(value?.trim() ?? '');
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

String _decodeHtmlAttribute(String value) {
  return value
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&sol;', '/')
      .replaceAllMapped(RegExp(r'&#(?:x([0-9a-fA-F]+)|([0-9]+));'), (match) {
        final codePoint = int.tryParse(
          match.group(1) ?? match.group(2)!,
          radix: match.group(1) == null ? 10 : 16,
        );
        if (codePoint == null) return match.group(0)!;
        return String.fromCharCode(codePoint);
      });
}

String? _contentType(String? value) {
  if (value == null) return null;
  return value.split(';').first.trim().toLowerCase();
}

String _extensionFor(Uri uri, String? mime) {
  return switch (mime) {
    'image/jpeg' || 'image/jpg' => '.jpg',
    'image/png' => '.png',
    'image/gif' => '.gif',
    'image/webp' => '.webp',
    'image/svg+xml' => '.svg',
    _ => switch (p.extension(uri.path).toLowerCase()) {
      '.jpg' ||
      '.jpeg' ||
      '.png' ||
      '.gif' ||
      '.webp' ||
      '.svg' => p.extension(uri.path).toLowerCase(),
      _ => '.jpg',
    },
  };
}

String _text(String value) => const HtmlEscape().convert(value);

String _attr(String value) => _text(value).replaceAll('"', '&quot;');
