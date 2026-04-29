import 'package:book_repository/book_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fsrs_repository/fsrs_repository.dart';
import 'package:highlight_repository/highlight_repository.dart';

part 'home_event.dart';

part 'home_state.dart';

/// Drives the Home tab dashboard.
///
/// Aggregates data from three repositories (books, highlights, FSRS) into
/// a single [HomeState] with totals + the top-5 recent books. Loads in a
/// single pass on [HomeLoadRequested] — there is no incremental refresh
/// yet; the tab is expected to be re-entered fresh via navigation.
class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc({
    required BookRepository bookRepository,
    required HighlightRepository highlightRepository,
    required FsrsRepository fsrsRepository,
  }) : _bookRepository = bookRepository,
       _highlightRepository = highlightRepository,
       _fsrsRepository = fsrsRepository,
       super(const HomeState()) {
    on<HomeLoadRequested>(_onLoadRequested);
  }

  final BookRepository _bookRepository;
  final HighlightRepository _highlightRepository;
  final FsrsRepository _fsrsRepository;

  Future<void> _onLoadRequested(
    HomeLoadRequested event,
    Emitter<HomeState> emit,
  ) async {
    emit(state.copyWith(status: HomeStatus.loading));

    try {
      final books = await _bookRepository.getBooks(limit: 20);
      final highlights = await _highlightRepository.getHighlights();
      final dueCards = await _fsrsRepository.getDueItems();

      emit(
        state.copyWith(
          status: HomeStatus.success,
          recentBooks: books,
          totalHighlights: highlights.length,
          dueFlashcards: dueCards.length,
        ),
      );
    } catch (e, st) {
      addError(e, st);
      emit(state.copyWith(status: HomeStatus.failure));
    }
  }
}
