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
/// Wraps [BooksDao] from `local_storage` and maps between storage and domain
/// models. Exceptions from the DAO propagate to callers (BLoCs).
class BookRepository {
  BookRepository({required BooksDao booksDao}) : _dao = booksDao;

  final BooksDao _dao;

  // ─── Books ───

  Future<List<Book>> getBooks() async {
    final rows = await _dao.allBooks();
    return rows.map((r) => r.toDomainModel()).toList();
  }

  Future<Book?> getBookById(String id) async {
    final row = await _dao.bookById(id);
    return row?.toDomainModel();
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
    await _dao.insertBook(book.toStorageModel());
    return book;
  }

  Future<Book> updateBook(Book book) async {
    await _dao.updateBook(book.toStorageModel());
    return book;
  }

  Future<void> deleteBook(String id) async {
    await _dao.deleteBook(id);
  }

  // ─── Articles ───

  Future<List<Article>> getArticles() async {
    final rows = await _dao.allArticles();
    return rows.map((r) => r.toDomainModel()).toList();
  }

  Future<Article?> getArticleById(String id) async {
    final row = await _dao.articleById(id);
    return row?.toDomainModel();
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
    await _dao.insertArticle(article.toStorageModel());
    return article;
  }

  Future<Article> updateArticle(Article article) async {
    await _dao.updateArticle(article.toStorageModel());
    return article;
  }

  Future<void> deleteArticle(String id) async {
    await _dao.deleteArticle(id);
  }
}
