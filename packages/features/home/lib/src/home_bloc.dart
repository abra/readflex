import 'package:book_repository/book_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flashcard_repository/flashcard_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:highlight_repository/highlight_repository.dart';
import 'package:shared/shared.dart';

part 'home_event.dart';
part 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc({
    required BookRepository bookRepository,
    required HighlightRepository highlightRepository,
    required FlashcardRepository flashcardRepository,
  }) : _bookRepository = bookRepository,
       _highlightRepository = highlightRepository,
       _flashcardRepository = flashcardRepository,
       super(const HomeState()) {
    on<HomeLoadRequested>(_onLoadRequested);
  }

  final BookRepository _bookRepository;
  final HighlightRepository _highlightRepository;
  final FlashcardRepository _flashcardRepository;

  Future<void> _onLoadRequested(
    HomeLoadRequested event,
    Emitter<HomeState> emit,
  ) async {
    emit(state.copyWith(status: HomeStatus.loading));

    try {
      final books = await _bookRepository.getBooks();
      final articles = await _bookRepository.getArticles();
      final highlights = await _highlightRepository.getHighlights();
      final dueCards = await _flashcardRepository.getDueFlashcards();

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
    } catch (e) {
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
