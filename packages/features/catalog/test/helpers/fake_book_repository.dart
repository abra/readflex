import 'package:book_repository/book_repository.dart';
import 'package:domain_models/domain_models.dart';

class FakeBookRepository implements BookRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  final List<Book> _books = [];
  bool shouldThrow = false;

  void seedBooks(List<Book> books) => _books
    ..clear()
    ..addAll(books);

  @override
  Future<List<Book>> getBooks({int? limit, int? offset}) async {
    if (shouldThrow) throw StorageException(cause: 'fake error');
    return List.unmodifiable(_books);
  }

  @override
  Future<void> deleteBook(
    String id, {
    BookDeletionScope scope = BookDeletionScope.keepLearningData,
  }) async {
    if (shouldThrow) throw StorageException(cause: 'fake error');
    _books.removeWhere((b) => b.id == id);
  }
}
