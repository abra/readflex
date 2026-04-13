part of 'content_library_bloc.dart';

sealed class ContentLibraryEvent {
  const ContentLibraryEvent();
}

final class ContentLibraryLoadRequested extends ContentLibraryEvent {
  const ContentLibraryLoadRequested();
}

final class ContentLibraryRefreshRequested extends ContentLibraryEvent {
  const ContentLibraryRefreshRequested();
}

final class ContentLibraryBookDeleted extends ContentLibraryEvent {
  const ContentLibraryBookDeleted(this.bookId);

  final String bookId;
}

final class ContentLibraryArticleDeleted extends ContentLibraryEvent {
  const ContentLibraryArticleDeleted(this.articleId);

  final String articleId;
}

final class ContentLibrarySearchQueryChanged extends ContentLibraryEvent {
  const ContentLibrarySearchQueryChanged(this.query);

  final String query;
}

final class ContentLibraryFilterChanged extends ContentLibraryEvent {
  const ContentLibraryFilterChanged(this.filter);

  final ContentLibraryFilter filter;
}
