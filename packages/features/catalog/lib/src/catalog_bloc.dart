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
      super(CatalogState()) {
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
      await _loadItems(emit, fromDeletion: true);
    } catch (e, st) {
      addError(e, st);
      emit(
        state.copyWith(
          status: CatalogStatus.failure,
          deletionVersion: state.deletionVersion + 1,
        ),
      );
    }
  }

  Future<void> _onBooksDeleted(
    CatalogBooksDeleted event,
    Emitter<CatalogState> emit,
  ) async {
    // Loop deliberately continues on per-id failure: if id #2 throws we
    // still try ids #3..N. Stopping early would leave the user with a
    // partial deletion they have no way to learn about — half the
    // selection gone, the other half still in the list, and a generic
    // failure toast that says nothing about the split.
    var anyFailed = false;
    for (final id in event.bookIds) {
      try {
        await _bookRepository.deleteBook(id, scope: event.scope);
      } catch (e, st) {
        anyFailed = true;
        addError(e, st);
      }
    }
    if (anyFailed) {
      // Re-pull the list so the rows that DID delete fall away from the
      // grid even though we're emitting the failure status.
      try {
        final books = await _bookRepository.getBooks();
        emit(
          state.copyWith(
            status: CatalogStatus.failure,
            books: books,
            deletionVersion: state.deletionVersion + 1,
          ),
        );
      } catch (e, st) {
        addError(e, st);
        emit(
          state.copyWith(
            status: CatalogStatus.failure,
            deletionVersion: state.deletionVersion + 1,
          ),
        );
      }
      return;
    }
    await _loadItems(emit, fromDeletion: true);
  }

  /// Pulls the latest book list and emits a `success` (or `failure`)
  /// state. Pass [fromDeletion] when this load is the post-delete
  /// refresh — that bumps `deletionVersion` so the screen's toast
  /// listener fires exactly once per delete dispatch, regardless of
  /// any other state changes that landed first.
  Future<void> _loadItems(
    Emitter<CatalogState> emit, {
    bool fromDeletion = false,
  }) async {
    try {
      final books = await _bookRepository.getBooks();
      emit(
        state.copyWith(
          status: CatalogStatus.success,
          books: books,
          deletionVersion: fromDeletion ? state.deletionVersion + 1 : null,
        ),
      );
    } catch (e, st) {
      addError(e, st);
      emit(
        state.copyWith(
          status: CatalogStatus.failure,
          deletionVersion: fromDeletion ? state.deletionVersion + 1 : null,
        ),
      );
    }
  }
}
