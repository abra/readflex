part of 'content_library_bloc.dart';

enum ContentLibraryStatus { initial, loading, success, failure }

/// Filter segments mirrored from the readwell_demo Library screen. Kept
/// as an enum (not a string) so switches are exhaustive and renames are
/// refactor-safe.
enum ContentLibraryFilter { all, books, articles, saved, finished }

class ContentLibraryState extends Equatable {
  const ContentLibraryState({
    this.status = ContentLibraryStatus.initial,
    this.books = const [],
    this.articles = const [],
    this.items = const [],
    this.filter = ContentLibraryFilter.all,
    this.searchQuery = '',
  });

  final ContentLibraryStatus status;
  final List<Book> books;
  final List<Article> articles;

  /// All items sorted by most recently added (pre-computed in bloc).
  /// Use [visibleItems] for the filtered/searched projection the UI
  /// should actually render.
  final List<Object> items;

  final ContentLibraryFilter filter;
  final String searchQuery;

  bool get isEmpty => books.isEmpty && articles.isEmpty;

  /// Total count shown in the header ("N items") — reflects the raw
  /// library size regardless of the active filter.
  int get totalCount => books.length + articles.length;

  /// Items after applying the current [filter] and [searchQuery]. This
  /// is what grid / list views iterate over. Kept as a getter (not a
  /// stored field) so the bloc doesn't have to recompute it on every
  /// state transition — BlocBuilder rebuilds only when inputs change.
  List<Object> get visibleItems {
    final trimmedQuery = searchQuery.trim().toLowerCase();

    return items.where((item) {
      // 1. Filter by segment.
      final matchesFilter = switch (filter) {
        ContentLibraryFilter.all => true,
        ContentLibraryFilter.books => item is Book,
        ContentLibraryFilter.articles => item is Article,
        ContentLibraryFilter.saved => switch (item) {
          Book book => !book.isFinished,
          Article article => !article.isFinished,
          _ => false,
        },
        ContentLibraryFilter.finished => switch (item) {
          Book book => book.isFinished,
          Article article => article.isFinished,
          _ => false,
        },
      };
      if (!matchesFilter) return false;

      // 2. Filter by search query (title / author-or-siteName).
      if (trimmedQuery.isEmpty) return true;
      final (title, secondary) = switch (item) {
        Book book => (book.title, book.author ?? ''),
        Article article => (article.title, article.siteName ?? ''),
        _ => ('', ''),
      };
      return title.toLowerCase().contains(trimmedQuery) ||
          secondary.toLowerCase().contains(trimmedQuery);
    }).toList();
  }

  ContentLibraryState copyWith({
    ContentLibraryStatus? status,
    List<Book>? books,
    List<Article>? articles,
    List<Object>? items,
    ContentLibraryFilter? filter,
    String? searchQuery,
  }) => ContentLibraryState(
    status: status ?? this.status,
    books: books ?? this.books,
    articles: articles ?? this.articles,
    items: items ?? this.items,
    filter: filter ?? this.filter,
    searchQuery: searchQuery ?? this.searchQuery,
  );

  @override
  List<Object?> get props => [
    status,
    books,
    articles,
    items,
    filter,
    searchQuery,
  ];
}
