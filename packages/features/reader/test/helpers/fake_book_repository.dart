import 'package:book_repository/book_repository.dart';
import 'package:shared/shared.dart';

class FakeBookRepository implements BookRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  bool shouldThrow = false;

  final List<Book> books = [];
  final List<Article> articles = [];

  Book? updatedBook;
  Article? updatedArticle;

  void seedBook(Book book) => books.add(book);

  void seedArticle(Article article) => articles.add(article);

  @override
  Future<Book?> getBookById(String id) async {
    if (shouldThrow) throw Exception('getBookById failed');
    return books.where((b) => b.id == id).firstOrNull;
  }

  @override
  Future<Book> updateBook(Book book) async {
    if (shouldThrow) throw Exception('updateBook failed');
    updatedBook = book;
    return book;
  }

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
