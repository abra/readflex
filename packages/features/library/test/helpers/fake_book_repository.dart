import 'package:book_repository/book_repository.dart';
import 'package:shared/shared.dart';

class FakeBookRepository extends BookRepository {
  final List<Book> _books = [];
  final List<Article> _articles = [];
  bool shouldThrow = false;

  void seedBooks(List<Book> books) => _books
    ..clear()
    ..addAll(books);

  void seedArticles(List<Article> articles) => _articles
    ..clear()
    ..addAll(articles);

  @override
  Future<List<Book>> getBooks() async {
    if (shouldThrow) throw StorageException(cause: 'fake error');
    return List.unmodifiable(_books);
  }

  @override
  Future<List<Article>> getArticles() async {
    if (shouldThrow) throw StorageException(cause: 'fake error');
    return List.unmodifiable(_articles);
  }

  @override
  Future<void> deleteBook(String id) async {
    if (shouldThrow) throw StorageException(cause: 'fake error');
    _books.removeWhere((b) => b.id == id);
  }

  @override
  Future<void> deleteArticle(String id) async {
    if (shouldThrow) throw StorageException(cause: 'fake error');
    _articles.removeWhere((a) => a.id == id);
  }
}
