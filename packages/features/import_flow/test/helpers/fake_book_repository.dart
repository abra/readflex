import 'package:book_repository/book_repository.dart';
import 'package:shared/shared.dart';

class FakeBookRepository extends BookRepository {
  final List<Article> addedArticles = [];
  bool shouldThrow = false;

  @override
  Future<Article> addArticle({
    required String title,
    required String url,
    required String cleanedHtml,
    String? siteName,
    String? coverImageUrl,
    int estimatedWordCount = 0,
  }) async {
    if (shouldThrow) throw StorageException(cause: 'fake error');
    final article = Article(
      id: 'generated-id',
      title: title,
      url: url,
      cleanedHtml: cleanedHtml,
      siteName: siteName,
      coverImageUrl: coverImageUrl,
      estimatedWordCount: estimatedWordCount,
      addedAt: DateTime.now(),
    );
    addedArticles.add(article);
    return article;
  }
}
