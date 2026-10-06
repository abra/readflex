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

sealed class LibraryQueryEvent extends LibraryEvent {
  const LibraryQueryEvent();
}

final class LibrarySearchQueryChanged extends LibraryQueryEvent {
  const LibrarySearchQueryChanged(this.query);

  final String query;
}

final class LibraryFiltersReset extends LibraryQueryEvent {
  const LibraryFiltersReset();
}

final class LibraryFilterChanged extends LibraryEvent {
  const LibraryFilterChanged(this.filter);

  final LibraryFilter filter;
}

final class LibraryCollectionScopeChanged extends LibraryEvent {
  const LibraryCollectionScopeChanged(this.scope);

  final LibraryCollectionScope? scope;
}
