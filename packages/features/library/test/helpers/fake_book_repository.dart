import 'package:book_repository/book_repository.dart';
import 'package:shared/shared.dart';

class FakeBookRepository implements BookRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  final List<Book> _books = [];
  bool shouldThrow = false;

  void seedBooks(List<Book> books) => _books
    ..clear()
    ..addAll(books);

  @override
  Future<List<Book>> getBooks() async {
    if (shouldThrow) throw StorageException(cause: 'fake error');
    return List.unmodifiable(_books);
  }

  @override
  Future<void> deleteBook(String id) async {
    if (shouldThrow) throw StorageException(cause: 'fake error');
    _books.removeWhere((b) => b.id == id);
  }
}
