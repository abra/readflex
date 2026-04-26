import 'dart:io';

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

/// Domain repository for articles.
///
/// Wraps [ArticlesDao] from `local_storage` and owns on-disk storage of
/// article content, cover images, and body images. Each article lives in
/// its own directory under [articlesDirectory]:
///
/// ```
/// articles/<uuid>/
///   content.html       — cleaned HTML from readability
///   cover.<ext>        — cover image (if available)
///   images/<hash>.ext  — downloaded body images
/// ```
///
/// The DB row stores only filenames (`content.html`, `cover.png`) for
/// each — this repo resolves filenames against the per-article directory
/// on every read, so the DB survives iOS Documents-UUID changes.
class ArticleRepository {
  ArticleRepository({
    required AppDatabase database,
    required Directory articlesDirectory,
    http.Client? httpClient,
    Logger? logger,
  }) : _db = database,
       _dao = database.articlesDao,
       _articlesDir = articlesDirectory,
       _ownsHttpClient = httpClient == null,
       _httpClient = httpClient ?? http.Client(),
       _logger = logger;

  final AppDatabase _db;
  final ArticlesDao _dao;
  final Directory _articlesDir;
  final http.Client _httpClient;
  final Logger? _logger;

  /// `true` when the [http.Client] was created internally; we close it on
  /// [dispose]. When the caller injects their own client (test fakes,
  /// app-wide pool) we leave the lifecycle to them.
  final bool _ownsHttpClient;

  static const _downloadTimeout = Duration(seconds: 30);

  /// Releases the internally-created HTTP client. Call from app shutdown
  /// (or test teardown) to avoid leaking sockets across long sessions.
  /// Idempotent: closing twice is safe.
  void dispose() {
    if (_ownsHttpClient) _httpClient.close();
  }

  Future<List<Article>> getArticles({int? limit, int? offset}) async {
    try {
      final rows = await _dao.allArticles(limit: limit, offset: offset);
      return rows.map(_rowToDomain).toList();
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  Future<Article?> getArticleById(String id) async {
    try {
      final row = await _dao.articleById(id);
      return row != null ? _rowToDomain(row) : null;
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  /// Reads the HTML body for [article] from disk. Throws [StorageException]
  /// if the file is missing or unreadable — a silent empty string would hide
  /// corrupted imports from the caller and from observability.
  Future<String> readContent(Article article) async {
    try {
      return await File(article.contentPath).readAsString();
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  /// Creates a new article from parsed content. Writes [content] to disk
  /// after downloading any referenced images. If [coverImageUrl] is set,
  /// best-effort downloads the cover image into the article directory.
  Future<Article> addArticle({
    required String title,
    required String url,
    required String content,
    String? siteName,
    String? byline,
    String? excerpt,
    String? publishedTime,
    String? lang,
    String? coverImageUrl,
    int textLength = 0,
    int estimatedWordCount = 0,
  }) async {
    final id = _uuid.v4();
    final articleDir = Directory(p.join(_articlesDir.path, id));
    try {
      final now = DateTime.now();

      await articleDir.create(recursive: true);

      // Download body images and rewrite HTML src to local relative paths.
      final downloadedContent = await _downloadArticleImages(
        articleDir,
        content,
      );
      // Wrap every <table> in a horizontal-scroll container before writing
      // to disk and packaging into the EPUB. foliate-js paginates inside
      // CSS columns; a table wider than the column gets clipped without an
      // overflow wrapper and the user has no way to see the cut-off cells.
      final processedContent = _wrapTablesInScrollContainer(downloadedContent);
      final contentFile = File(p.join(articleDir.path, 'content.html'));
      await contentFile.writeAsString(processedContent);

      String? coverFilename;
      if (coverImageUrl != null && coverImageUrl.isNotEmpty) {
        coverFilename = await _tryDownloadCover(articleDir, coverImageUrl);
      }

      // Build the EPUB synchronously with the rest of the import — the
      // reader expects every article to have an `article.epub` file
      // (foliate-js renders it through the same pipeline as books). If
      // packaging fails, the whole import fails and we clean up below
      // so we never leave a half-imported article that the reader can't
      // open.
      await _buildArticleEpub(
        articleDir: articleDir,
        articleId: id,
        title: title,
        author: byline,
        lang: lang,
        htmlBody: processedContent,
      );

      final article = Article(
        id: id,
        title: title,
        url: url,
        contentPath: contentFile.path,
        addedAt: now,
        siteName: siteName,
        byline: byline,
        excerpt: excerpt,
        publishedTime: publishedTime,
        lang: lang,
        coverImageUrl: coverImageUrl,
        coverImagePath: coverFilename != null
            ? p.join(articleDir.path, coverFilename)
            : null,
        textLength: textLength,
        estimatedWordCount: estimatedWordCount,
      );
      await _dao.insertArticle(article.toStorageModel());
      return article;
    } catch (e, st) {
      // The DB row was never inserted (insertArticle is the last step).
      // Roll back the on-disk side too so a failed import doesn't leak
      // the per-article directory; otherwise repeated failed imports
      // accumulate orphaned dirs that nothing in the app references.
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

  /// Deletes the article and every dependent row in a single
  /// transaction — highlights, flashcards, dictionary entries, plus the
  /// review-scheduler state tied to each. Mirrors `BookRepository.deleteBook`.
  Future<void> deleteArticle(String id) async {
    try {
      await _db.transaction(() async {
        await _db.reviewItemsDao.deleteItemsBySource(id);
        await _db.highlightsDao.deleteHighlightsBySource(id);
        await _db.flashcardsDao.deleteFlashcardsByDeck(id);
        await _db.dictionaryDao.deleteEntriesBySource(id);
        await _dao.deleteArticle(id);
      });
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
    // Best-effort cleanup — orphaned dirs get reclaimed on maintenance pass.
    final articleDir = Directory(p.join(_articlesDir.path, id));
    await _tryDeleteDirectory(articleDir);
  }

  Article _rowToDomain(ArticlesTableData row) => row.toDomainModel(
    articlesDir: _articlesDir,
  );

  // ── HTML transforms ──

  static final _tableOpenRegex = RegExp(
    r'<table\b',
    caseSensitive: false,
  );
  static final _tableCloseRegex = RegExp(
    r'</table\s*>',
    caseSensitive: false,
  );

  /// Wraps every `<table>` in `<div class="rf-table-scroll">…</div>` so a
  /// wide table renders with a horizontal scrollbar inside the page rather
  /// than being silently clipped at the column edge. Idempotent on regular
  /// readability output: if a table happens to already sit inside such a
  /// wrapper, we simply nest a second one — at worst slightly redundant
  /// markup, never broken layout.
  static String _wrapTablesInScrollContainer(String html) {
    if (!html.contains('<table') && !html.contains('<TABLE')) return html;
    final withOpen = html.replaceAllMapped(
      _tableOpenRegex,
      (m) => '<div class="rf-table-scroll"><table',
    );
    return withOpen.replaceAllMapped(
      _tableCloseRegex,
      (m) => '${m.group(0)}</div>',
    );
  }

  // ── Image downloading ──

  static final _imgSrcRegex = RegExp(
    r'''<img[^>]+src=["']([^"']+)["']''',
    caseSensitive: false,
  );

  /// Downloads images referenced in [html] to [articleDir]/images/ and
  /// rewrites their `src` to relative `images/<hash>.<ext>` paths.
  /// Images that fail to download keep their original URL.
  Future<String> _downloadArticleImages(
    Directory articleDir,
    String html,
  ) async {
    final matches = _imgSrcRegex.allMatches(html);

    // Collect unique HTTP(S) image URLs.
    final urls = <String>{};
    for (final match in matches) {
      final url = match.group(1)!;
      if (url.startsWith('http')) urls.add(url);
    }
    if (urls.isEmpty) return html;

    final imagesDir = Directory(p.join(articleDir.path, 'images'));
    await imagesDir.create(recursive: true);

    // Download all unique URLs in parallel, then build a replacement map.
    final urlList = urls.toList();
    final downloaded = await Future.wait(
      urlList.map((url) => _tryDownloadImage(imagesDir, url)),
    );
    final replacements = <String, String>{};
    for (var i = 0; i < urlList.length; i++) {
      final filename = downloaded[i];
      if (filename != null) {
        replacements[urlList[i]] = 'images/$filename';
      }
    }
    if (replacements.isEmpty) return html;

    // Single-pass replacement via regex union of all original URLs.
    final pattern = RegExp(
      replacements.keys.map(RegExp.escape).join('|'),
    );
    return html.replaceAllMapped(
      pattern,
      (m) => replacements[m.group(0)] ?? m.group(0)!,
    );
  }

  /// Best-effort image download. Returns the local filename on success,
  /// null on any failure.
  Future<String?> _tryDownloadImage(Directory imagesDir, String url) async {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null) return null;
      final response = await _httpClient.get(uri).timeout(_downloadTimeout);
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        return null;
      }
      final ext = _extensionFor(uri, response.headers['content-type']);
      final hash = url.hashCode
          .toUnsigned(32)
          .toRadixString(16)
          .padLeft(
            8,
            '0',
          );
      final filename = '$hash$ext';
      await File(p.join(imagesDir.path, filename)).writeAsBytes(
        response.bodyBytes,
      );
      return filename;
    } catch (e, st) {
      // Silent return is by design — the article is still usable with the
      // original remote URL — but the failure is logged so a flaky CDN or
      // unsupported image format shows up in observability instead of
      // silently disappearing.
      _logger?.debug(
        'ArticleRepository: image download failed ($url)',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  /// Best-effort cover download. Returns the local filename (e.g. `cover.png`)
  /// on success, null on failure.
  Future<String?> _tryDownloadCover(
    Directory articleDir,
    String url,
  ) async {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null || !uri.hasScheme) return null;
      final response = await _httpClient.get(uri).timeout(_downloadTimeout);
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        return null;
      }
      final ext = _extensionFor(uri, response.headers['content-type']);
      final filename = 'cover$ext';
      await File(p.join(articleDir.path, filename)).writeAsBytes(
        response.bodyBytes,
      );
      return filename;
    } catch (e, st) {
      _logger?.debug(
        'ArticleRepository: cover download failed ($url)',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  static String _extensionFor(Uri uri, String? contentType) {
    final fromPath = p.extension(uri.path).toLowerCase();
    if (fromPath.isNotEmpty && fromPath.length <= 5) {
      return fromPath;
    }
    if (contentType == null) return '.img';
    final lower = contentType.toLowerCase();
    if (lower.contains('jpeg') || lower.contains('jpg')) return '.jpg';
    if (lower.contains('png')) return '.png';
    if (lower.contains('webp')) return '.webp';
    if (lower.contains('gif')) return '.gif';
    return '.img';
  }

  // ── EPUB packaging ──

  /// Packages the saved article HTML + downloaded images into a single
  /// EPUB at `<articleDir>/article.epub`. Reads each image referenced by
  /// the EPUB manifest from disk so we don't hold the whole media set in
  /// memory while building.
  Future<void> _buildArticleEpub({
    required Directory articleDir,
    required String articleId,
    required String title,
    required String? author,
    required String? lang,
    required String htmlBody,
  }) async {
    final imagesDir = Directory(p.join(articleDir.path, 'images'));
    final images = <EpubImage>[];
    if (await imagesDir.exists()) {
      await for (final entry in imagesDir.list()) {
        if (entry is! File) continue;
        final filename = p.basename(entry.path);
        images.add(
          EpubImage(
            filename: filename,
            bytes: await entry.readAsBytes(),
            mimeType: EpubBuilder.mimeTypeFor(filename),
          ),
        );
      }
    }

    await const EpubBuilder().build(
      id: articleId,
      title: title,
      author: author,
      lang: lang,
      htmlBody: htmlBody,
      images: images,
      outputFile: File(p.join(articleDir.path, 'article.epub')),
    );
  }

  // ── Cleanup helpers ──

  Future<void> _tryDeleteDirectory(Directory dir) async {
    try {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (e, st) {
      // Best-effort — the DB row is already gone, so the user-visible
      // delete succeeded; log for observability but don't surface.
      _logger?.warn(
        'ArticleRepository: failed to delete article directory ${dir.path}',
        error: e,
        stackTrace: st,
      );
    }
  }
}
