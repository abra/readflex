import 'package:book_repository/book_repository.dart';
import 'package:domain_models/domain_models.dart';

class FakeBookRepository implements BookRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  List<Book> books = [];
  bool shouldThrow = false;
  int? lastLimitPassed;

  @override
  Future<List<Book>> getBooks({int? limit, int? offset}) async {
    if (shouldThrow) throw StorageException(cause: 'fake');
    lastLimitPassed = limit;
    return books;
  }
}
