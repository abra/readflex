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

  @override
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

  @override
  Article updateFromReaderBook(Article article, Book readerBook) {
    return article.copyWith(
      currentCfi: readerBook.currentCfi,
      readingProgress: readerBook.readingProgress,
      lastOpenedAt: readerBook.lastOpenedAt,
      isFinished: readerBook.isFinished,
    );
  }
}
