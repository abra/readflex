part of 'catalog_bloc.dart';

enum CatalogStatus { initial, loading, success, failure }

/// Filter segments mirrored from the readwell_demo Library screen. Kept
/// as an enum (not a string) so switches are exhaustive and renames are
/// refactor-safe.
enum CatalogFilter { all, books, articles, comics, unread, finished }

class CatalogDeletionEffect extends Equatable {
  const CatalogDeletionEffect({
    required this.version,
    required this.success,
    required this.count,
    this.singleTitle,
  });

  final int version;
  final bool success;
  final int count;
  final String? singleTitle;

  @override
  List<Object?> get props => [version, success, count, singleTitle];
}

class CatalogState extends Equatable {
  // Non-const because [visibleItems] is a `late final` derived field —
  // const objects can't have late initializers. The trade-off is the
  // 8 `const CatalogState(...)` literals in tests/bloc-init lose their
  // compile-time canonical form, which is irrelevant at runtime.
  CatalogState({
    this.status = CatalogStatus.initial,
    this.books = const [],
    this.articles = const [],
    this.filter = CatalogFilter.all,
    this.searchQuery = '',
    this.deletionVersion = 0,
    this.deletionEffect,
  });

  final CatalogStatus status;
  final List<Book> books;
  final List<Article> articles;

  late final List<LibrarySource> sources = [
    ...books.map(LibrarySource.fromBook),
    ...articles.map(LibrarySource.fromArticle),
  ];

  final CatalogFilter filter;
  final String searchQuery;

  /// Monotonic counter bumped exactly once per dispatched delete event
  /// (success OR failure). Used as the identity of [deletionEffect] so
  /// listeners can distinguish consecutive delete completions.
  final int deletionVersion;

  /// One-shot UI effect emitted after a delete finishes. The screen listens
  /// for changes and renders the toast; it no longer owns delete queues.
  final CatalogDeletionEffect? deletionEffect;

  bool get isEmpty => sources.isEmpty;

  /// Total count shown in the header ("N items") — reflects the raw
  /// library size regardless of the active filter.
  int get totalCount => sources.length;

  /// Sources after applying the current [filter] and [searchQuery],
  /// sorted by most-recently-opened first, then by newest added.
  ///
  /// Cached: `late final` evaluates [_computeVisibleItems] once per
  /// state instance and reuses the result. Earlier this was a getter
  /// that re-ran filter + lowercase + sort on every read — `BlocBuilder`
  /// reads it on every rebuild, so the same list was being computed
  /// dozens of times for the same state.
  ///
  /// Not in [props]: derived from already-compared fields, so two
  /// states with equal raw inputs already produce the same list.
  late final List<LibrarySource> visibleItems = _computeVisibleItems(
    sources: sources,
    filter: filter,
    searchQuery: searchQuery,
  );

  static List<LibrarySource> _computeVisibleItems({
    required List<LibrarySource> sources,
    required CatalogFilter filter,
    required String searchQuery,
  }) {
    final trimmedQuery = searchQuery.trim().toLowerCase();

    final filtered = sources.where((source) {
      final matchesFilter = switch (filter) {
        CatalogFilter.all => true,
        CatalogFilter.books =>
          source.sourceType == SourceType.book && !source.isComic,
        CatalogFilter.articles => source.sourceType == SourceType.article,
        CatalogFilter.comics => source.isComic,
        CatalogFilter.unread => source.readingProgress == 0,
        CatalogFilter.finished => source.isFinished,
      };
      if (!matchesFilter) return false;

      if (trimmedQuery.isEmpty) return true;
      final title = source.title.toLowerCase();
      final author = (source.author ?? '').toLowerCase();
      return title.contains(trimmedQuery) || author.contains(trimmedQuery);
    }).toList();

    filtered.sort((a, b) {
      final recencyA = a.lastOpenedAt ?? a.addedAt;
      final recencyB = b.lastOpenedAt ?? b.addedAt;

      final byRecency = recencyB.compareTo(recencyA);
      if (byRecency != 0) return byRecency;

      final byAddedAt = b.addedAt.compareTo(a.addedAt);
      if (byAddedAt != 0) return byAddedAt;

      return a.title.compareTo(b.title);
    });
    return filtered;
  }

  CatalogState copyWith({
    CatalogStatus? status,
    List<Book>? books,
    List<Article>? articles,
    CatalogFilter? filter,
    String? searchQuery,
    int? deletionVersion,
    CatalogDeletionEffect? deletionEffect,
  }) => CatalogState(
    status: status ?? this.status,
    books: books ?? this.books,
    articles: articles ?? this.articles,
    filter: filter ?? this.filter,
    searchQuery: searchQuery ?? this.searchQuery,
    deletionVersion: deletionVersion ?? this.deletionVersion,
    deletionEffect: deletionEffect ?? this.deletionEffect,
  );

  @override
  List<Object?> get props => [
    status,
    books,
    articles,
    filter,
    searchQuery,
    deletionVersion,
    deletionEffect,
  ];
}
