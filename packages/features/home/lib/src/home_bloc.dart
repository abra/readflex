import 'package:article_repository/article_repository.dart';
import 'package:book_repository/book_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fsrs_repository/fsrs_repository.dart';
import 'package:highlight_repository/highlight_repository.dart';

part 'home_event.dart';

part 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc({
    required BookRepository bookRepository,
    required ArticleRepository articleRepository,
    required HighlightRepository highlightRepository,
    required FsrsRepository fsrsRepository,
  }) : _bookRepository = bookRepository,
       _articleRepository = articleRepository,
       _highlightRepository = highlightRepository,
       _fsrsRepository = fsrsRepository,
       super(const HomeState()) {
    on<HomeLoadRequested>(_onLoadRequested);
  }

  final BookRepository _bookRepository;
  final ArticleRepository _articleRepository;
  final HighlightRepository _highlightRepository;
  final FsrsRepository _fsrsRepository;

  Future<void> _onLoadRequested(
    HomeLoadRequested event,
    Emitter<HomeState> emit,
  ) async {
    emit(state.copyWith(status: HomeStatus.loading));

    try {
      // Home surfaces the top-5 recent items; 20 each gives plenty of headroom
      // for the lastOpenedAt-sorted merge without hauling the whole library in.
      final books = await _bookRepository.getBooks(limit: 20);
      final articles = await _articleRepository.getArticles(limit: 20);
      final highlights = await _highlightRepository.getHighlights();
      final dueCards = await _fsrsRepository.getDueItems();

      emit(
        state.copyWith(
          status: HomeStatus.success,
          recentBooks: books,
          recentArticles: articles,
          recentItems: _recentItems(books, articles),
          totalHighlights: highlights.length,
          dueFlashcards: dueCards.length,
        ),
      );
    } catch (e, st) {
      addError(e, st);
      emit(state.copyWith(status: HomeStatus.failure));
    }
  }

  static List<Object> _recentItems(List<Book> books, List<Article> articles) {
    final all = <({DateTime date, Object item})>[
      for (final b in books) (date: b.lastOpenedAt ?? b.addedAt, item: b),
      for (final a in articles) (date: a.lastOpenedAt ?? a.addedAt, item: a),
    ];
    all.sort((a, b) => b.date.compareTo(a.date));
    return all.take(5).map((e) => e.item).toList();
  }
}
