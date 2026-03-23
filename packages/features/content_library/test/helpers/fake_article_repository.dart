import 'package:article_repository/article_repository.dart';
import 'package:domain_models/domain_models.dart';

class FakeArticleRepository implements ArticleRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  final List<Article> _articles = [];
  bool shouldThrow = false;

  void seedArticles(List<Article> articles) => _articles
    ..clear()
    ..addAll(articles);

  @override
  Future<List<Article>> getArticles() async {
    if (shouldThrow) throw StorageException(cause: 'fake error');
    return List.unmodifiable(_articles);
  }

  @override
  Future<void> deleteArticle(String id) async {
    if (shouldThrow) throw StorageException(cause: 'fake error');
    _articles.removeWhere((a) => a.id == id);
  }
}
