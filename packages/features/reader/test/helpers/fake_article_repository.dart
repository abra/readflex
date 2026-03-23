import 'package:article_repository/article_repository.dart';
import 'package:domain_models/domain_models.dart';

class FakeArticleRepository implements ArticleRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  bool shouldThrow = false;

  final List<Article> articles = [];

  Article? updatedArticle;

  void seedArticle(Article article) => articles.add(article);

  @override
  Future<Article?> getArticleById(String id) async {
    if (shouldThrow) throw Exception('getArticleById failed');
    return articles.where((a) => a.id == id).firstOrNull;
  }

  @override
  Future<Article> updateArticle(Article article) async {
    if (shouldThrow) throw Exception('updateArticle failed');
    updatedArticle = article;
    return article;
  }
}
