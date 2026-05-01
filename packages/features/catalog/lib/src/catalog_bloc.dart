import 'package:book_repository/book_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:stream_transform/stream_transform.dart';

part 'catalog_event.dart';
part 'catalog_state.dart';

class CatalogBloc extends Bloc<CatalogEvent, CatalogState> {
  CatalogBloc({required BookRepository bookRepository})
    : _bookRepository = bookRepository,
      super(const CatalogState()) {
    on<CatalogLoadRequested>(_onLoadRequested);
    on<CatalogBookDeleted>(_onBookDeleted);
    on<CatalogBooksDeleted>(_onBooksDeleted);
    on<CatalogRefreshRequested>(_onRefreshRequested);
    on<CatalogSearchQueryChanged>(
      _onSearchQueryChanged,
      transformer: _debounce(_searchDelay),
    );
    on<CatalogFilterChanged>(_onFilterChanged);
  }

  static const _searchDelay = Duration(milliseconds: 300);

  static EventTransformer<E> _debounce<E>(Duration duration) {
    return (events, mapper) => events.debounce(duration).asyncExpand(mapper);
  }

  void _onSearchQueryChanged(
    CatalogSearchQueryChanged event,
    Emitter<CatalogState> emit,
  ) {
    emit(state.copyWith(searchQuery: event.query));
  }

  void _onFilterChanged(
    CatalogFilterChanged event,
    Emitter<CatalogState> emit,
  ) {
    emit(state.copyWith(filter: event.filter));
  }

  final BookRepository _bookRepository;

  Future<void> _onLoadRequested(
    CatalogLoadRequested event,
    Emitter<CatalogState> emit,
  ) async {
    emit(state.copyWith(status: CatalogStatus.loading));
    await _loadItems(emit);
  }

  Future<void> _onRefreshRequested(
    CatalogRefreshRequested event,
    Emitter<CatalogState> emit,
  ) async {
    await _loadItems(emit);
  }

  Future<void> _onBookDeleted(
    CatalogBookDeleted event,
    Emitter<CatalogState> emit,
  ) async {
    try {
      await _bookRepository.deleteBook(event.bookId, scope: event.scope);
      await _loadItems(emit);
    } catch (e, st) {
      addError(e, st);
      emit(state.copyWith(status: CatalogStatus.failure));
    }
  }

  Future<void> _onBooksDeleted(
    CatalogBooksDeleted event,
    Emitter<CatalogState> emit,
  ) async {
    try {
      for (final id in event.bookIds) {
        await _bookRepository.deleteBook(id, scope: event.scope);
      }
      await _loadItems(emit);
    } catch (e, st) {
      addError(e, st);
      emit(state.copyWith(status: CatalogStatus.failure));
    }
  }

  Future<void> _loadItems(Emitter<CatalogState> emit) async {
    try {
      final books = await _bookRepository.getBooks();
      emit(state.copyWith(status: CatalogStatus.success, books: books));
    } catch (e, st) {
      addError(e, st);
      emit(state.copyWith(status: CatalogStatus.failure));
    }
  }
}
