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

final class LibraryBookDeleted extends LibraryEvent {
  const LibraryBookDeleted(this.bookId);
  final String bookId;
}

final class LibraryArticleDeleted extends LibraryEvent {
  const LibraryArticleDeleted(this.articleId);
  final String articleId;
}
