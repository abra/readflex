import 'dart:async';

import 'package:article_repository/article_repository.dart';
import 'package:book_repository/book_repository.dart';
import 'package:collection_repository/collection_repository.dart';
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
    CollectionRepository? collectionRepository,
  }) : _bookRepository = bookRepository,
       _articleRepository = articleRepository,
       _collectionRepository = collectionRepository,
       super(LibraryState()) {
    on<LibraryLoadRequested>(_onLoadRequested);
    on<LibrarySourceDeleted>(_onSourceDeleted);
    on<LibrarySourcesDeleted>(_onSourcesDeleted);
    on<LibraryRefreshRequested>(_onRefreshRequested);
    on<LibraryQueryEvent>(
      _onQueryEvent,
      transformer: (events, mapper) => events
          .switchMap(
            (event) =>
                event is LibrarySearchQueryChanged && event.query.isNotEmpty
                ? Stream.value(event).debounce(_searchDelay)
                : Stream.value(event),
          )
          .asyncExpand(mapper),
    );
    on<LibraryCollectionScopeChanged>(_onCollectionScopeChanged);
  }

  static const _searchDelay = Duration(milliseconds: 300);

  // Reset shares the search stream so a debounced query cannot come back.
  void _onQueryEvent(
    LibraryQueryEvent event,
    Emitter<LibraryState> emit,
  ) {
    switch (event) {
      case LibrarySearchQueryChanged(:final query):
        emit(state.copyWith(searchQuery: query));
      case LibraryFiltersReset():
        emit(state.copyWith(searchQuery: '', selectedCollectionScope: null));
    }
  }

  void _onCollectionScopeChanged(
    LibraryCollectionScopeChanged event,
    Emitter<LibraryState> emit,
  ) {
    emit(state.copyWith(selectedCollectionScope: event.scope));
  }

  final BookRepository _bookRepository;
  final ArticleRepository? _articleRepository;
  final CollectionRepository? _collectionRepository;
  int _loadGeneration = 0;

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
    try {
      await _loadItems(emit);
    } finally {
      event.completer?.complete();
    }
  }

  Future<void> _onSourceDeleted(
    LibrarySourceDeleted event,
    Emitter<LibraryState> emit,
  ) async {
    _loadGeneration++;
    final deletion = _deletionDescriptorFor({event.sourceId});
    var deleted = true;
    try {
      await _deleteSource(event.sourceId, event.scope);
    } catch (e, st) {
      deleted = false;
      addError(e, st);
    }
    // A failed delete still re-reads storage: the list must show what is
    // really there, not an unchanged copy of the pre-delete list.
    await _loadItems(emit, deletion: deletion, deletionSuccess: deleted);
  }

  Future<void> _onSourcesDeleted(
    LibrarySourcesDeleted event,
    Emitter<LibraryState> emit,
  ) async {
    _loadGeneration++;
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
    // Keep successful deletions visible even when another item failed.
    await _loadItems(emit, deletion: deletion, deletionSuccess: !anyFailed);
  }

  /// Pulls the latest source list and emits a `success` (or `failure`)
  /// state. Pass [deletion] when this load is the post-delete
  /// refresh — that emits a [LibraryDeletionEffect] so the screen can show
  /// the correct toast without tracking a local queue.
  Future<void> _loadItems(
    Emitter<LibraryState> emit, {
    _LibraryDeletionDescriptor? deletion,
    bool deletionSuccess = true,
  }) async {
    final generation = ++_loadGeneration;
    try {
      final snapshot = await _loadLibrarySnapshot();
      if (emit.isDone) return;
      final effect = deletion == null
          ? null
          : _deletionEffect(deletion, success: deletionSuccess);
      if (generation != _loadGeneration) {
        // A mutation still deserves feedback, but its older list must not win.
        if (effect != null) {
          emit(
            state.copyWith(
              deletionVersion: effect.version,
              deletionEffect: effect,
            ),
          );
        }
        return;
      }
      final scopes = [
        ..._buildBuiltInScopes(snapshot.sources),
        // A failed read is not an empty collection. Keep the last valid data.
        ...snapshot.collectionScopes ??
            state.collectionScopes.where((scope) => scope.canManage),
        ..._buildSiteScopes(snapshot.sources),
        ..._buildAuthorScopes(snapshot.sources),
      ];
      emit(
        state.copyWith(
          status: LibraryStatus.success,
          sources: snapshot.sources,
          collectionScopes: scopes,
          collectionsLoadFailed: snapshot.collectionScopes == null,
          selectedCollectionScope: _resolveSelectedCollectionScope(
            state.selectedCollectionScope,
            scopes,
          ),
          deletionVersion: effect?.version,
          deletionEffect: effect,
        ),
      );
    } catch (e, st) {
      addError(e, st);
      if (emit.isDone) return;
      final effect = deletion == null
          ? null
          : _deletionEffect(deletion, success: false);
      if (generation != _loadGeneration) {
        if (effect != null) {
          emit(
            state.copyWith(
              deletionVersion: effect.version,
              deletionEffect: effect,
            ),
          );
        }
        return;
      }
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

  Future<_LibrarySnapshot> _loadLibrarySnapshot() async {
    final (books, articles) = await (
      _bookRepository.getBooks(),
      _articleRepository?.getLibrarySources() ??
          Future.value(const <LibrarySource>[]),
    ).wait;
    final sources = [
      ...books.map(LibrarySource.fromBook),
      ...articles,
    ];
    List<LibraryCollectionScope>? collectionScopes;
    try {
      collectionScopes = [
        await _loadFavouriteCollectionScope(),
        ...await _loadManualCollectionScopes(),
      ];
    } catch (e, st) {
      addError(e, st);
    }
    return _LibrarySnapshot(
      sources: sources,
      collectionScopes: collectionScopes,
    );
  }

  Future<LibraryCollectionScope> _loadFavouriteCollectionScope() async {
    final collectionRepository = _collectionRepository;
    if (collectionRepository == null) {
      return LibraryCollectionScope.favourites();
    }

    final sourceIds = await collectionRepository.getFavouriteSourceIds();
    return LibraryCollectionScope.favourites(sourceIds: sourceIds);
  }

  Future<List<LibraryCollectionScope>> _loadManualCollectionScopes() async {
    final collectionRepository = _collectionRepository;
    if (collectionRepository == null) return const [];

    final collections = await collectionRepository.getCollections();
    final sourceIdsByCollection = await collectionRepository
        .getCollectionSourceIds();
    return collections
        .map(
          (collection) => LibraryCollectionScope.manual(
            collection: collection,
            sourceIds: sourceIdsByCollection[collection.id] ?? const {},
          ),
        )
        .toList(growable: false);
  }

  /// Book, article, comic and New scopes with their counts, in one pass.
  /// Always all four, even when empty, so a selected one that empties (the
  /// last new item opened) stays selected rather than jumping to Library.
  List<LibraryCollectionScope> _buildBuiltInScopes(
    List<LibrarySource> sources,
  ) {
    final counts = {
      for (final type in LibraryCollectionScopeType.builtIn) type: 0,
    };
    for (final source in sources) {
      for (final type in LibraryCollectionScopeType.builtIn) {
        if (libraryBuiltInScopeMatches(type, source)) {
          counts[type] = counts[type]! + 1;
        }
      }
    }
    return [
      for (final type in LibraryCollectionScopeType.builtIn)
        LibraryCollectionScope.smart(
          type: type,
          id: type.name,
          // Shown localized; the id keeps the scope stable across locales.
          label: type.name,
          sourceCount: counts[type]!,
        ),
    ];
  }

  List<LibraryCollectionScope> _buildSiteScopes(List<LibrarySource> sources) {
    return _buildSmartScopes(
      sources: sources,
      type: LibraryCollectionScopeType.site,
      labelFor: _siteLabelForSource,
    );
  }

  List<LibraryCollectionScope> _buildAuthorScopes(List<LibrarySource> sources) {
    return _buildSmartScopes(
      sources: sources,
      type: LibraryCollectionScopeType.author,
      labelFor: _authorLabelForSource,
    );
  }

  List<LibraryCollectionScope> _buildSmartScopes({
    required List<LibrarySource> sources,
    required LibraryCollectionScopeType type,
    required String? Function(LibrarySource source) labelFor,
  }) {
    final groups = <String, _SmartCollectionGroup>{};
    for (final source in sources) {
      final label = labelFor(source)?.trim();
      if (label == null || label.isEmpty) continue;
      final id = _collectionScopeKey(label);
      if (id.isEmpty) continue;
      groups
          .putIfAbsent(id, () => _SmartCollectionGroup(label: label))
          .sourceIds
          .add(source.id);
    }

    final scopes = groups.entries
        .map(
          (entry) => LibraryCollectionScope.smart(
            type: type,
            id: entry.key,
            label: entry.value.label,
            sourceCount: entry.value.sourceIds.length,
          ),
        )
        .toList();
    scopes.sort(
      (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
    );
    return scopes;
  }

  LibraryCollectionScope? _resolveSelectedCollectionScope(
    LibraryCollectionScope? selected,
    List<LibraryCollectionScope> scopes,
  ) {
    if (selected == null) return null;
    for (final scope in scopes) {
      if (scope.type == selected.type && scope.id == selected.id) {
        return scope;
      }
    }
    return null;
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
    final idSet = Set.unmodifiable(ids);
    return _LibraryDeletionDescriptor(
      sourceIds: idSet,
      singleTitle: idSet.length == 1 ? _titleOf(idSet.first) : null,
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
      sourceIds: deletion.sourceIds,
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

/// Stable deletion metadata captured before the source list refreshes.
///
/// The toast needs the old title/count even after the deleted row disappears
/// from [LibraryState.sources].
class _LibraryDeletionDescriptor {
  const _LibraryDeletionDescriptor({
    required this.sourceIds,
    this.singleTitle,
  });

  final Set<String> sourceIds;
  final String? singleTitle;
}

/// Complete repository snapshot loaded in one BLoC operation.
class _LibrarySnapshot {
  const _LibrarySnapshot({
    required this.sources,
    required this.collectionScopes,
  });

  final List<LibrarySource> sources;
  final List<LibraryCollectionScope>? collectionScopes;
}

/// Temporary accumulator for smart collection scopes derived from source
/// metadata rather than persisted collections.
class _SmartCollectionGroup {
  _SmartCollectionGroup({required this.label});

  final String label;
  final Set<String> sourceIds = {};
}
