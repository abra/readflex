import 'package:article_repository/article_repository.dart';
import 'package:book_repository/book_repository.dart';
import 'package:domain_models/domain_models.dart';

/// Every library source by id, for naming where words and highlights came
/// from. Loaded once per screen load.
class PracticeSourceIndex {
  const PracticeSourceIndex(this._sources);

  static const empty = PracticeSourceIndex({});

  final Map<String, LibrarySource> _sources;

  static Future<PracticeSourceIndex> load({
    required BookRepository bookRepository,
    ArticleRepository? articleRepository,
  }) async {
    final (books, articles) = await (
      bookRepository.getBooks(),
      articleRepository?.getLibrarySources() ??
          Future.value(const <LibrarySource>[]),
    ).wait;
    return PracticeSourceIndex({
      for (final book in books) book.id: LibrarySource.fromBook(book),
      for (final article in articles) article.id: article,
    });
  }

  LibrarySource? operator [](String? id) => id == null ? null : _sources[id];

  String? titleOf(String? id) => this[id]?.title;

  Iterable<LibrarySource> get sources => _sources.values;
}
