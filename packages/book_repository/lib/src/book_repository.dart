import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:local_storage/local_storage.dart';
import 'package:shared/shared.dart';
import 'package:uuid/uuid.dart' show Uuid;

import 'mappers/article_to_domain.dart';
import 'mappers/article_to_storage.dart';
import 'mappers/book_to_domain.dart';
import 'mappers/book_to_storage.dart';

const _uuid = Uuid();

/// Domain repository for books and articles.
///
/// Wraps [BooksDao] from `local_storage`, maps between storage and domain
/// models, and translates storage exceptions into [StorageException].
class BookRepository {
  BookRepository({@visibleForTesting BooksDao? booksDao}) : _dao = booksDao;

  BooksDao? _dao;

  void init(BooksDao dao) => _dao = dao;

  BooksDao get _books {
    final dao = _dao;
    if (dao == null) {
      throw StateError('BookRepository not initialized. Call init() first.');
    }
    return dao;
  }

  // ─── Books ───

  Future<List<Book>> getBooks() async {
    try {
      final rows = await _books.allBooks();
      return rows.map((r) => r.toDomainModel()).toList();
    } catch (e) {
      throw StorageException(cause: e);
    }
  }

  Future<Book?> getBookById(String id) async {
    try {
      final row = await _books.bookById(id);
      return row?.toDomainModel();
    } catch (e) {
      throw StorageException(cause: e);
    }
  }

  Future<Book> addBook({
    required String title,
    required String filePath,
    required BookFormat format,
    String? author,
    String? coverImagePath,
    int totalLocations = 0,
  }) async {
    final now = DateTime.now();
    final book = Book(
      id: _uuid.v4(),
      title: title,
      filePath: filePath,
      format: format,
      addedAt: now,
      author: author,
      coverImagePath: coverImagePath,
      totalLocations: totalLocations,
    );
    try {
      await _books.insertBook(book.toStorageModel());
    } catch (e) {
      throw StorageException(cause: e);
    }
    return book;
  }

  Future<Book> updateBook(Book book) async {
    try {
      await _books.updateBook(book.toStorageModel());
    } catch (e) {
      throw StorageException(cause: e);
    }
    return book;
  }

  Future<void> deleteBook(String id) async {
    try {
      await _books.deleteBook(id);
    } catch (e) {
      throw StorageException(cause: e);
    }
  }

  // ─── Articles ───

  Future<List<Article>> getArticles() async {
    try {
      final rows = await _books.allArticles();
      return rows.map((r) => r.toDomainModel()).toList();
    } catch (e) {
      throw StorageException(cause: e);
    }
  }

  Future<Article?> getArticleById(String id) async {
    try {
      final row = await _books.articleById(id);
      return row?.toDomainModel();
    } catch (e) {
      throw StorageException(cause: e);
    }
  }

  Future<Article> addArticle({
    required String title,
    required String url,
    required String cleanedHtml,
    String? siteName,
    String? coverImageUrl,
    int estimatedWordCount = 0,
  }) async {
    final now = DateTime.now();
    final article = Article(
      id: _uuid.v4(),
      title: title,
      url: url,
      cleanedHtml: cleanedHtml,
      addedAt: now,
      siteName: siteName,
      coverImageUrl: coverImageUrl,
      estimatedWordCount: estimatedWordCount,
    );
    try {
      await _books.insertArticle(article.toStorageModel());
    } catch (e) {
      throw StorageException(cause: e);
    }
    return article;
  }

  Future<Article> updateArticle(Article article) async {
    try {
      await _books.updateArticle(article.toStorageModel());
    } catch (e) {
      throw StorageException(cause: e);
    }
    return article;
  }

  Future<void> deleteArticle(String id) async {
    try {
      await _books.deleteArticle(id);
    } catch (e) {
      throw StorageException(cause: e);
    }
  }
}
