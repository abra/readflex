part of 'library_bloc.dart';

enum LibraryStatus { initial, loading, success, failure }

final class LibraryState extends Equatable {
  const LibraryState({
    this.status = LibraryStatus.initial,
    this.books = const [],
    this.articles = const [],
    this.items = const [],
  });

  final LibraryStatus status;
  final List<Book> books;
  final List<Article> articles;

  /// All items sorted by most recently added (pre-computed in bloc).
  final List<Object> items;

  bool get isEmpty => books.isEmpty && articles.isEmpty;

  LibraryState copyWith({
    LibraryStatus? status,
    List<Book>? books,
    List<Article>? articles,
    List<Object>? items,
  }) => LibraryState(
    status: status ?? this.status,
    books: books ?? this.books,
    articles: articles ?? this.articles,
    items: items ?? this.items,
  );

  @override
  List<Object?> get props => [status, books, articles, items];
}
