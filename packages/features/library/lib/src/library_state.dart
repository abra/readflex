part of 'library_bloc.dart';

enum LibraryStatus { initial, loading, success, failure }

final class LibraryState extends Equatable {
  const LibraryState({
    this.status = LibraryStatus.initial,
    this.books = const [],
    this.articles = const [],
  });

  final LibraryStatus status;
  final List<Book> books;
  final List<Article> articles;

  /// All items sorted by most recently added.
  List<Object> get items {
    final all = <({DateTime addedAt, Object item})>[
      for (final b in books) (addedAt: b.addedAt, item: b),
      for (final a in articles) (addedAt: a.addedAt, item: a),
    ];
    all.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return all.map((e) => e.item).toList();
  }

  bool get isEmpty => books.isEmpty && articles.isEmpty;

  LibraryState copyWith({
    LibraryStatus? status,
    List<Book>? books,
    List<Article>? articles,
  }) => LibraryState(
    status: status ?? this.status,
    books: books ?? this.books,
    articles: articles ?? this.articles,
  );

  @override
  List<Object?> get props => [status, books, articles];
}
