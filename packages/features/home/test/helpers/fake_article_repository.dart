import 'package:article_repository/article_repository.dart';
import 'package:domain_models/domain_models.dart';

class FakeArticleRepository implements ArticleRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  List<Article> articles = [];
  bool shouldThrow = false;
  int? lastLimitPassed;

  @override
  Future<List<Article>> getArticles({int? limit, int? offset}) async {
    if (shouldThrow) throw StorageException(cause: 'fake');
    lastLimitPassed = limit;
    return articles;
  }
}
