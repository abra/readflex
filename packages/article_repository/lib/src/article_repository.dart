import 'package:local_storage/local_storage.dart';
import 'package:domain_models/domain_models.dart';
import 'package:uuid/uuid.dart' show Uuid;

import 'mappers/article_to_domain.dart';
import 'mappers/article_to_storage.dart';

const _uuid = Uuid();

/// Domain repository for articles.
///
/// Wraps [ArticlesDao] from `local_storage` and maps between storage and domain
/// models. Exceptions from the DAO propagate to callers (BLoCs).
class ArticleRepository {
  ArticleRepository({required ArticlesDao articlesDao}) : _dao = articlesDao;

  final ArticlesDao _dao;

  Future<List<Article>> getArticles() async {
    final rows = await _dao.allArticles();
    return rows.map((r) => r.toDomainModel()).toList();
  }

  Future<Article?> getArticleById(String id) async {
    final row = await _dao.articleById(id);
    return row?.toDomainModel();
  }

  Future<Article> addArticle({
    required String title,
    required String url,
    required String cleanedHtml,
    String? siteName,
    String? coverImageUrl,
    int estimatedWordCount = 0,
  }) async {
    final now = DateTime.now();
    final article = Article(
      id: _uuid.v4(),
      title: title,
      url: url,
      cleanedHtml: cleanedHtml,
      addedAt: now,
      siteName: siteName,
      coverImageUrl: coverImageUrl,
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
  }
}
