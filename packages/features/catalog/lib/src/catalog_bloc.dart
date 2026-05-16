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
    final deletion = _deletionDescriptorFor({event.bookId});
    try {
      await _bookRepository.deleteBook(event.bookId, scope: event.scope);
      await _loadItems(emit, deletion: deletion);
    } catch (e, st) {
      addError(e, st);
      final effect = _deletionEffect(deletion, success: false);
      emit(
        state.copyWith(
          status: CatalogStatus.success,
          deletionVersion: effect.version,
          deletionEffect: effect,
        ),
      );
    }
  }

  Future<void> _onBooksDeleted(
    CatalogBooksDeleted event,
    Emitter<CatalogState> emit,
  ) async {
    final deletion = _deletionDescriptorFor(event.bookIds);
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
      // grid. Keep the screen in success because the list remains usable;
      // the error is surfaced through the deletion effect/toast.
      try {
        final books = await _bookRepository.getBooks();
        final effect = _deletionEffect(deletion, success: false);
        emit(
          state.copyWith(
            status: CatalogStatus.success,
            books: books,
            deletionVersion: effect.version,
            deletionEffect: effect,
          ),
        );
      } catch (e, st) {
        addError(e, st);
        final effect = _deletionEffect(deletion, success: false);
        emit(
          state.copyWith(
            status: CatalogStatus.success,
            deletionVersion: effect.version,
            deletionEffect: effect,
          ),
        );
      }
      return;
    }
    await _loadItems(emit, deletion: deletion);
  }

  /// Pulls the latest book list and emits a `success` (or `failure`)
  /// state. Pass [fromDeletion] when this load is the post-delete
  /// refresh — that emits a [CatalogDeletionEffect] so the screen can show
  /// the correct toast without tracking a local queue.
  Future<void> _loadItems(
    Emitter<CatalogState> emit, {
    _CatalogDeletionDescriptor? deletion,
  }) async {
    try {
      final books = await _bookRepository.getBooks();
      final effect = deletion == null
          ? null
          : _deletionEffect(deletion, success: true);
      emit(
        state.copyWith(
          status: CatalogStatus.success,
          books: books,
          deletionVersion: effect?.version,
          deletionEffect: effect,
        ),
      );
    } catch (e, st) {
      addError(e, st);
      final effect = deletion == null
          ? null
          : _deletionEffect(deletion, success: false);
      final status = deletion == null
          ? CatalogStatus.failure
          : CatalogStatus.success;
      emit(
        state.copyWith(
          status: status,
          deletionVersion: effect?.version,
          deletionEffect: effect,
        ),
      );
    }
  }

  _CatalogDeletionDescriptor _deletionDescriptorFor(Iterable<String> ids) {
    final idList = ids.toList(growable: false);
    return _CatalogDeletionDescriptor(
      count: idList.length,
      singleTitle: idList.length == 1 ? _titleOf(idList.first) : null,
    );
  }

  CatalogDeletionEffect _deletionEffect(
    _CatalogDeletionDescriptor deletion, {
    required bool success,
  }) {
    final version = state.deletionVersion + 1;
    return CatalogDeletionEffect(
      version: version,
      success: success,
      count: deletion.count,
      singleTitle: deletion.singleTitle,
    );
  }

  String? _titleOf(String id) {
    for (final book in state.books) {
      if (book.id == id) return book.title;
    }
    return null;
  }
}

class _CatalogDeletionDescriptor {
  const _CatalogDeletionDescriptor({
    required this.count,
    this.singleTitle,
  });

  final int count;
  final String? singleTitle;
}
