import 'package:article_repository/article_repository.dart';
import 'package:domain_models/domain_models.dart';

class FakeArticleRepository implements ArticleRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  final List<Article> articles = [];

  Article? updatedArticle;
  int updateCallCount = 0;

  void seedArticle(Article article) => articles.add(article);

  @override
  Future<Article?> getArticleById(String id) async {
    return articles.where((article) => article.id == id).firstOrNull;
  }

  @override
  Future<Article> updateArticle(Article article) async {
    updatedArticle = article;
    updateCallCount += 1;
    final index = articles.indexWhere((existing) => existing.id == article.id);
    if (index == -1) {
      articles.add(article);
    } else {
      articles[index] = article;
    }
    return article;
  }
}
