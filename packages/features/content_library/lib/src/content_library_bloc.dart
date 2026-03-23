import 'package:article_repository/article_repository.dart';
import 'package:book_repository/book_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared/shared.dart';

part 'content_library_event.dart';
part 'content_library_state.dart';

class ContentLibraryBloc
    extends Bloc<ContentLibraryEvent, ContentLibraryState> {
  ContentLibraryBloc({
    required BookRepository bookRepository,
    required ArticleRepository articleRepository,
  }) : _bookRepository = bookRepository,
       _articleRepository = articleRepository,
       super(const ContentLibraryState()) {
    on<ContentLibraryLoadRequested>(_onLoadRequested);
    on<ContentLibraryBookDeleted>(_onBookDeleted);
    on<ContentLibraryArticleDeleted>(_onArticleDeleted);
    on<ContentLibraryRefreshRequested>(_onRefreshRequested);
  }

  final BookRepository _bookRepository;
  final ArticleRepository _articleRepository;

  Future<void> _onLoadRequested(
    ContentLibraryLoadRequested event,
    Emitter<ContentLibraryState> emit,
  ) async {
    emit(state.copyWith(status: ContentLibraryStatus.loading));
    await _loadItems(emit);
  }

  Future<void> _onRefreshRequested(
    ContentLibraryRefreshRequested event,
    Emitter<ContentLibraryState> emit,
  ) async {
    await _loadItems(emit);
  }

  Future<void> _onBookDeleted(
    ContentLibraryBookDeleted event,
    Emitter<ContentLibraryState> emit,
  ) async {
    try {
      await _bookRepository.deleteBook(event.bookId);
      await _loadItems(emit);
    } catch (e) {
      emit(state.copyWith(status: ContentLibraryStatus.failure));
    }
  }

  Future<void> _onArticleDeleted(
    ContentLibraryArticleDeleted event,
    Emitter<ContentLibraryState> emit,
  ) async {
    try {
      await _articleRepository.deleteArticle(event.articleId);
      await _loadItems(emit);
    } catch (e) {
      emit(state.copyWith(status: ContentLibraryStatus.failure));
    }
  }

  Future<void> _loadItems(Emitter<ContentLibraryState> emit) async {
    try {
      final books = await _bookRepository.getBooks();
      final articles = await _articleRepository.getArticles();
      emit(
        state.copyWith(
          status: ContentLibraryStatus.success,
          books: books,
          articles: articles,
          items: _sortedItems(books, articles),
        ),
      );
    } catch (e) {
      emit(state.copyWith(status: ContentLibraryStatus.failure));
    }
  }

  static List<Object> _sortedItems(List<Book> books, List<Article> articles) {
    final all = <({DateTime addedAt, Object item})>[
      for (final b in books) (addedAt: b.addedAt, item: b),
      for (final a in articles) (addedAt: a.addedAt, item: a),
    ];
    all.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return all.map((e) => e.item).toList();
  }
}
