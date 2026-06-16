import 'package:article_repository/article_repository.dart';
import 'package:domain_models/domain_models.dart';

class FakeArticleRepository implements ArticleRepository {
  final articles = <Article>[];
  bool shouldThrow = false;

  void seed(Article article) => articles.add(article);

  @override
  Future<Article?> getArticleById(String id) async {
    if (shouldThrow) throw Exception('getArticleById failed');
    for (final article in articles) {
      if (article.id == id) return article;
    }
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
