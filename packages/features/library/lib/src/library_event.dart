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

/// Recounts the review queue without reloading books or collections.
final class LibraryPracticeRefreshRequested extends LibraryEvent {
  const LibraryPracticeRefreshRequested();
}

/// Suspends deadline work in the background and catches up on resume.
final class LibraryForegroundChanged extends LibraryEvent {
  const LibraryForegroundChanged(this.isForeground);

  final bool isForeground;
}

/// The reader saved [progress] for [sourceId]. A save changes nothing else
/// the Library shows, so the bloc updates that source without reading
/// storage.
final class LibrarySourceProgressSaved extends LibraryEvent {
  const LibrarySourceProgressSaved(this.sourceId, this.progress);

  final String sourceId;
  final double progress;
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
