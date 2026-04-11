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
/// article content and cover images. Article HTML is written to
/// [articlesDirectory] as `<id>.html`; cover images are downloaded to
/// [coversDirectory]. The DB row only stores paths, keeping list queries
/// cheap regardless of article length.
///
/// Exceptions from the DAO and file I/O propagate to callers (BLoCs).
class ArticleRepository {
  ArticleRepository({
    required AppDatabase database,
    required Directory articlesDirectory,
    required Directory coversDirectory,
    http.Client? httpClient,
  }) : _dao = database.articlesDao,
       _articlesDir = articlesDirectory,
       _coversDir = coversDirectory,
       _httpClient = httpClient ?? http.Client();

  final ArticlesDao _dao;
  final Directory _articlesDir;
  final Directory _coversDir;
  final http.Client _httpClient;

  Future<List<Article>> getArticles() async {
    final rows = await _dao.allArticles();
    return rows.map((r) => r.toDomainModel()).toList();
  }

  Future<Article?> getArticleById(String id) async {
    final row = await _dao.articleById(id);
    return row?.toDomainModel();
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
  /// and, if [coverImageUrl] is set, best-effort downloads the cover image
  /// to the covers directory. Failure to download the cover does not fail
  /// the whole import — the article is still saved without a local cover.
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

    await _articlesDir.create(recursive: true);
    final contentFile = File(p.join(_articlesDir.path, '$id.html'));
    await contentFile.writeAsString(content);

    String? coverImagePath;
    if (coverImageUrl != null && coverImageUrl.isNotEmpty) {
      coverImagePath = await _tryDownloadCover(id, coverImageUrl);
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
      coverImagePath: coverImagePath,
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
    final row = await _dao.articleById(id);
    if (row != null) {
      await _tryDelete(File(row.contentPath));
      final coverPath = row.coverImagePath;
      if (coverPath != null) {
        await _tryDelete(File(coverPath));
      }
    }
    await _dao.deleteArticle(id);
  }

  Future<String?> _tryDownloadCover(String articleId, String url) async {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null || !uri.hasScheme) return null;
      final response = await _httpClient.get(uri);
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        return null;
      }
      await _coversDir.create(recursive: true);
      final ext = _extensionFor(uri, response.headers['content-type']);
      final file = File(p.join(_coversDir.path, '$articleId$ext'));
      await file.writeAsBytes(response.bodyBytes);
      return file.path;
    } catch (_) {
      // Cover download is best-effort; failures are swallowed so a flaky
      // CDN can't block the rest of the import. The article will simply
      // render the placeholder until a later re-import or sync.
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

  Future<void> _tryDelete(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // File cleanup is best-effort — orphaned files get reclaimed on the
      // next maintenance pass, and we don't want a failing delete to
      // block the DB row from being removed.
    }
  }
}
