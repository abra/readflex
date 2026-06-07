import 'package:article_repository/article_repository.dart';
import 'package:book_repository/book_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:stream_transform/stream_transform.dart';

part 'library_event.dart';
part 'library_state.dart';

class LibraryBloc extends Bloc<LibraryEvent, LibraryState> {
  LibraryBloc({
    required BookRepository bookRepository,
    ArticleRepository? articleRepository,
  }) : _bookRepository = bookRepository,
       _articleRepository = articleRepository,
       super(LibraryState()) {
    on<LibraryLoadRequested>(_onLoadRequested);
    on<LibrarySourceDeleted>(_onSourceDeleted);
    on<LibrarySourcesDeleted>(_onSourcesDeleted);
    on<LibraryRefreshRequested>(_onRefreshRequested);
    on<LibrarySearchQueryChanged>(
      _onSearchQueryChanged,
      transformer: _debounce(_searchDelay),
    );
    on<LibraryFilterChanged>(_onFilterChanged);
  }

  static const _searchDelay = Duration(milliseconds: 300);

  static EventTransformer<E> _debounce<E>(Duration duration) {
    return (events, mapper) => events.debounce(duration).asyncExpand(mapper);
  }

  void _onSearchQueryChanged(
    LibrarySearchQueryChanged event,
    Emitter<LibraryState> emit,
  ) {
    emit(state.copyWith(searchQuery: event.query));
  }

  void _onFilterChanged(
    LibraryFilterChanged event,
    Emitter<LibraryState> emit,
  ) {
    emit(state.copyWith(filter: event.filter));
  }

  final BookRepository _bookRepository;
  final ArticleRepository? _articleRepository;

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

  Future<void> _onSourceDeleted(
    LibrarySourceDeleted event,
    Emitter<LibraryState> emit,
  ) async {
    final deletion = _deletionDescriptorFor({event.sourceId});
    try {
      await _deleteSource(event.sourceId, event.scope);
      await _loadItems(emit, deletion: deletion);
    } catch (e, st) {
      addError(e, st);
      final effect = _deletionEffect(deletion, success: false);
      emit(
        state.copyWith(
          status: LibraryStatus.success,
          deletionVersion: effect.version,
          deletionEffect: effect,
        ),
      );
    }
  }

  Future<void> _onSourcesDeleted(
    LibrarySourcesDeleted event,
    Emitter<LibraryState> emit,
  ) async {
    final deletion = _deletionDescriptorFor(event.sourceIds);
    // Loop deliberately continues on per-id failure: if id #2 throws we
    // still try ids #3..N. Stopping early would leave the user with a
    // partial deletion they have no way to learn about — half the
    // selection gone, the other half still in the list, and a generic
    // failure toast that says nothing about the split.
    var anyFailed = false;
    for (final id in event.sourceIds) {
      try {
        await _deleteSource(id, event.scope);
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
        final (books, articles) = await _loadRawSources();
        final effect = _deletionEffect(deletion, success: false);
        emit(
          state.copyWith(
            status: LibraryStatus.success,
            books: books,
            articles: articles,
            deletionVersion: effect.version,
            deletionEffect: effect,
          ),
        );
      } catch (e, st) {
        addError(e, st);
        final effect = _deletionEffect(deletion, success: false);
        emit(
          state.copyWith(
            status: LibraryStatus.success,
            deletionVersion: effect.version,
            deletionEffect: effect,
          ),
        );
      }
      return;
    }
    await _loadItems(emit, deletion: deletion);
  }

  /// Pulls the latest source list and emits a `success` (or `failure`)
  /// state. Pass [fromDeletion] when this load is the post-delete
  /// refresh — that emits a [LibraryDeletionEffect] so the screen can show
  /// the correct toast without tracking a local queue.
  Future<void> _loadItems(
    Emitter<LibraryState> emit, {
    _LibraryDeletionDescriptor? deletion,
  }) async {
    try {
      final (books, articles) = await _loadRawSources();
      final effect = deletion == null
          ? null
          : _deletionEffect(deletion, success: true);
      emit(
        state.copyWith(
          status: LibraryStatus.success,
          books: books,
          articles: articles,
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
          ? LibraryStatus.failure
          : LibraryStatus.success;
      emit(
        state.copyWith(
          status: status,
          deletionVersion: effect?.version,
          deletionEffect: effect,
        ),
      );
    }
  }

  Future<(List<Book>, List<Article>)> _loadRawSources() async {
    final articleRepository = _articleRepository;
    if (articleRepository == null) {
      return (await _bookRepository.getBooks(), const <Article>[]);
    }
    return (
      await _bookRepository.getBooks(),
      await articleRepository.getArticles(),
    );
  }

  Future<void> _deleteSource(String id, BookDeletionScope scope) async {
    final source = _sourceOf(id);
    if (source?.sourceType == SourceType.article) {
      await _articleRepository?.deleteArticle(id);
      return;
    }
    await _bookRepository.deleteBook(id, scope: scope);
  }

  _LibraryDeletionDescriptor _deletionDescriptorFor(Iterable<String> ids) {
    final idList = ids.toList(growable: false);
    return _LibraryDeletionDescriptor(
      count: idList.length,
      singleTitle: idList.length == 1 ? _titleOf(idList.first) : null,
    );
  }

  LibraryDeletionEffect _deletionEffect(
    _LibraryDeletionDescriptor deletion, {
    required bool success,
  }) {
    final version = state.deletionVersion + 1;
    return LibraryDeletionEffect(
      version: version,
      success: success,
      count: deletion.count,
      singleTitle: deletion.singleTitle,
    );
  }

  String? _titleOf(String id) {
    for (final source in state.sources) {
      if (source.id == id) return source.title;
    }
    return null;
  }

  LibrarySource? _sourceOf(String id) {
    for (final source in state.sources) {
      if (source.id == id) return source;
    }
    return null;
  }
}

class _LibraryDeletionDescriptor {
  const _LibraryDeletionDescriptor({
    required this.count,
    this.singleTitle,
  });

  final int count;
  final String? singleTitle;
}
