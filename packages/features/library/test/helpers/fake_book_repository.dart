import 'dart:async';

import 'package:book_repository/book_repository.dart';
import 'package:domain_models/domain_models.dart';

class FakeBookRepository implements BookRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  final List<Book> _books = [];
  bool shouldThrow = false;
  int getBooksCallCount = 0;

  /// Specific ids whose `deleteBook` throws a [StorageException]. Used
  /// to simulate partial-failure bulk deletes without affecting other
  /// ids in the same batch.
  Set<String> failOnIds = const {};

  /// When set, `deleteBook` waits for it before writing, so a test can
  /// observe the UI while a delete is in flight.
  Completer<void>? deleteGate;

  /// When set, `getBooks` waits for it, so a test can observe loading.
  Completer<void>? getBooksGate;

  void seedBooks(List<Book> books) => _books
    ..clear()
    ..addAll(books);

  @override
  Future<List<Book>> getBooks({int? limit, int? offset}) async {
    getBooksCallCount++;
    await getBooksGate?.future;
    if (shouldThrow) throw StorageException(cause: 'fake error');
    return List.unmodifiable(_books);
  }

  @override
  Future<void> deleteBook(
    String id, {
    BookDeletionScope scope = BookDeletionScope.keepLearningData,
  }) async {
    await deleteGate?.future;
    if (shouldThrow || failOnIds.contains(id)) {
      throw StorageException(cause: 'fake error');
    }
    _books.removeWhere((b) => b.id == id);
  }
}
