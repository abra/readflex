part of 'library_bloc.dart';

sealed class LibraryEvent {
  const LibraryEvent();
}

final class LibraryLoadRequested extends LibraryEvent {
  const LibraryLoadRequested();
}

final class LibraryRefreshRequested extends LibraryEvent {
  const LibraryRefreshRequested({this.completer});

  /// Completed when the reload has finished, so pull-to-refresh can keep its
  /// indicator up for exactly that long (an unchanged state emits nothing).
  final Completer<void>? completer;
}

final class LibrarySourceDeleted extends LibraryEvent {
  const LibrarySourceDeleted(this.sourceId, {required this.scope});

  final String sourceId;
  final BookDeletionScope scope;
}

final class LibrarySourcesDeleted extends LibraryEvent {
  const LibrarySourcesDeleted(this.sourceIds, {required this.scope});

  final Set<String> sourceIds;
  final BookDeletionScope scope;
}

/// A new search query. An empty query (clearing the search) applies at once
/// and cancels a pending debounced one.
final class LibrarySearchQueryChanged extends LibraryEvent {
  const LibrarySearchQueryChanged(this.query);

  final String query;
}

final class LibraryCollectionScopeChanged extends LibraryEvent {
  const LibraryCollectionScopeChanged(this.scope);

  final LibraryCollectionScope? scope;
}
