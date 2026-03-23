part of 'content_library_bloc.dart';

enum ContentLibraryStatus { initial, loading, success, failure }

final class ContentLibraryState extends Equatable {
  const ContentLibraryState({
    this.status = ContentLibraryStatus.initial,
    this.books = const [],
    this.articles = const [],
    this.items = const [],
  });

  final ContentLibraryStatus status;
  final List<Book> books;
  final List<Article> articles;

  /// All items sorted by most recently added (pre-computed in bloc).
  final List<Object> items;

  bool get isEmpty => books.isEmpty && articles.isEmpty;

  ContentLibraryState copyWith({
    ContentLibraryStatus? status,
    List<Book>? books,
    List<Article>? articles,
    List<Object>? items,
  }) => ContentLibraryState(
    status: status ?? this.status,
    books: books ?? this.books,
    articles: articles ?? this.articles,
    items: items ?? this.items,
  );

  @override
  List<Object?> get props => [status, books, articles, items];
}
