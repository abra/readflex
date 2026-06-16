import 'package:book_repository/book_repository.dart';
import 'package:domain_models/domain_models.dart';

class FakeBookRepository implements BookRepository {
  final books = <Book>[];
  bool shouldThrow = false;

  void seed(Book book) => books.add(book);

  @override
  Future<Book?> getBookById(String id) async {
    if (shouldThrow) throw Exception('getBookById failed');
    for (final book in books) {
      if (book.id == id) return book;
    }
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
