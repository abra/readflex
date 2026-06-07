part of 'library_bloc.dart';

sealed class LibraryEvent {
  const LibraryEvent();
}

final class LibraryLoadRequested extends LibraryEvent {
  const LibraryLoadRequested();
}

final class LibraryRefreshRequested extends LibraryEvent {
  const LibraryRefreshRequested();
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

final class LibrarySearchQueryChanged extends LibraryEvent {
  const LibrarySearchQueryChanged(this.query);

  final String query;
}

final class LibraryFilterChanged extends LibraryEvent {
  const LibraryFilterChanged(this.filter);

  final LibraryFilter filter;
}
