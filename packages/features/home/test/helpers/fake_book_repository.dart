import 'package:book_repository/book_repository.dart';
import 'package:shared/shared.dart';

class FakeBookRepository extends BookRepository {
  List<Book> books = [];
  List<Article> articles = [];
  bool shouldThrow = false;

  @override
  Future<List<Book>> getBooks() async {
    if (shouldThrow) throw StorageException(cause: 'fake');
    return books;
  }

  @override
  Future<List<Article>> getArticles() async {
    if (shouldThrow) throw StorageException(cause: 'fake');
    return articles;
  }
}
