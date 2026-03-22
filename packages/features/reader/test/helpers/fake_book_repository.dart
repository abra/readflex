import 'package:book_repository/book_repository.dart';
import 'package:shared/shared.dart';

class FakeBookRepository implements BookRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  bool shouldThrow = false;

  final List<Book> books = [];

  Book? updatedBook;

  void seedBook(Book book) => books.add(book);

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
}
