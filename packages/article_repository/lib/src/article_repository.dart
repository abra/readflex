import 'dart:io';

import 'package:domain_models/domain_models.dart';
import 'package:http/http.dart' as http;
import 'package:local_storage/local_storage.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart' show Uuid;

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
  }) : _dao = database.articlesDao,
       _articlesDir = articlesDirectory,
       _httpClient = httpClient ?? http.Client();

  final ArticlesDao _dao;
  final Directory _articlesDir;
  final http.Client _httpClient;

  Future<List<Article>> getArticles() async {
    final rows = await _dao.allArticles();
    return rows.map(_rowToDomain).toList();
  }

  Future<Article?> getArticleById(String id) async {
    final row = await _dao.articleById(id);
    return row != null ? _rowToDomain(row) : null;
  }

  /// Reads the HTML body for [article] from disk. Returns an empty string
  /// if the file is missing — the caller (reader) can decide whether to
  /// treat that as a corrupt import or re-fetch.
  Future<String> readContent(Article article) async {
    final file = File(article.contentPath);
    if (!await file.exists()) return '';
    return file.readAsString();
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
    final now = DateTime.now();

    final articleDir = Directory(p.join(_articlesDir.path, id));
    await articleDir.create(recursive: true);

    // Download body images and rewrite HTML src to local relative paths.
    final processedContent = await _downloadArticleImages(articleDir, content);
    final contentFile = File(p.join(articleDir.path, 'content.html'));
    await contentFile.writeAsString(processedContent);

    String? coverFilename;
    if (coverImageUrl != null && coverImageUrl.isNotEmpty) {
      coverFilename = await _tryDownloadCover(articleDir, coverImageUrl);
    }

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
  }

  Future<Article> updateArticle(Article article) async {
    await _dao.updateArticle(article.toStorageModel());
    return article;
  }

  Future<void> deleteArticle(String id) async {
    await _dao.deleteArticle(id);
    // Remove the entire article directory (content + cover + images).
    final articleDir = Directory(p.join(_articlesDir.path, id));
    await _tryDeleteDirectory(articleDir);
  }

  Article _rowToDomain(ArticlesTableData row) => row.toDomainModel(
    articlesDir: _articlesDir,
  );

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

    // Download each unique URL and build a replacement map.
    final replacements = <String, String>{};
    for (final url in urls) {
      final localFilename = await _tryDownloadImage(imagesDir, url);
      if (localFilename != null) {
        replacements[url] = 'images/$localFilename';
      }
    }

    // Apply replacements in one pass.
    var result = html;
    for (final entry in replacements.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }
    return result;
  }

  /// Best-effort image download. Returns the local filename on success,
  /// null on any failure.
  Future<String?> _tryDownloadImage(Directory imagesDir, String url) async {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null) return null;
      final response = await _httpClient.get(uri);
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
    } catch (_) {
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
      final response = await _httpClient.get(uri);
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        return null;
      }
      final ext = _extensionFor(uri, response.headers['content-type']);
      final filename = 'cover$ext';
      await File(p.join(articleDir.path, filename)).writeAsBytes(
        response.bodyBytes,
      );
      return filename;
    } catch (_) {
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

  // ── Cleanup helpers ──

  Future<void> _tryDeleteDirectory(Directory dir) async {
    try {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {
      // Best-effort — orphaned dirs get reclaimed on maintenance pass.
    }
  }
}
