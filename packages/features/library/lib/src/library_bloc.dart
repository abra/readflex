import 'package:book_repository/book_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared/shared.dart';

part 'library_event.dart';
part 'library_state.dart';

class LibraryBloc extends Bloc<LibraryEvent, LibraryState> {
  LibraryBloc({required BookRepository bookRepository})
    : _bookRepository = bookRepository,
      super(const LibraryState()) {
    on<LibraryLoadRequested>(_onLoadRequested);
    on<LibraryBookDeleted>(_onBookDeleted);
    on<LibraryArticleDeleted>(_onArticleDeleted);
    on<LibraryRefreshRequested>(_onRefreshRequested);
  }

  final BookRepository _bookRepository;

  Future<void> _onLoadRequested(
    LibraryLoadRequested event,
    Emitter<LibraryState> emit,
  ) async {
    emit(state.copyWith(status: LibraryStatus.loading));
    await _loadItems(emit);
  }

  Future<void> _onRefreshRequested(
    LibraryRefreshRequested event,
    Emitter<LibraryState> emit,
  ) async {
    await _loadItems(emit);
  }

  Future<void> _onBookDeleted(
    LibraryBookDeleted event,
    Emitter<LibraryState> emit,
  ) async {
    try {
      await _bookRepository.deleteBook(event.bookId);
      await _loadItems(emit);
    } catch (e) {
      emit(state.copyWith(status: LibraryStatus.failure));
    }
  }

  Future<void> _onArticleDeleted(
    LibraryArticleDeleted event,
    Emitter<LibraryState> emit,
  ) async {
    try {
      await _bookRepository.deleteArticle(event.articleId);
      await _loadItems(emit);
    } catch (e) {
      emit(state.copyWith(status: LibraryStatus.failure));
    }
  }

  Future<void> _loadItems(Emitter<LibraryState> emit) async {
    try {
      final books = await _bookRepository.getBooks();
      final articles = await _bookRepository.getArticles();
      emit(
        state.copyWith(
          status: LibraryStatus.success,
          books: books,
          articles: articles,
        ),
      );
    } catch (e) {
      emit(state.copyWith(status: LibraryStatus.failure));
    }
  }
}
