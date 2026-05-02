part of 'catalog_bloc.dart';

enum CatalogStatus { initial, loading, success, failure }

/// Filter segments mirrored from the readwell_demo Library screen. Kept
/// as an enum (not a string) so switches are exhaustive and renames are
/// refactor-safe.
enum CatalogFilter { all, books, comics, saved, finished }

class CatalogState extends Equatable {
  const CatalogState({
    this.status = CatalogStatus.initial,
    this.books = const [],
    this.filter = CatalogFilter.all,
    this.searchQuery = '',
    this.deletionVersion = 0,
  });

  final CatalogStatus status;
  final List<Book> books;

  final CatalogFilter filter;
  final String searchQuery;

  /// Monotonic counter bumped exactly once per dispatched delete event
  /// (success OR failure). The screen pairs each delete with a queued
  /// descriptor and pops one off the queue every time the version
  /// changes; this is what stops cross-batch toast races (delete A
  /// dispatched, delete B dispatched, A finishes but the screen-local
  /// "pending title" had already been overwritten by B).
  final int deletionVersion;

  bool get isEmpty => books.isEmpty;

  /// Total count shown in the header ("N items") — reflects the raw
  /// library size regardless of the active filter.
  int get totalCount => books.length;

  /// Books after applying the current [filter] and [searchQuery],
  /// sorted by most-recently-added first.
  List<Book> get visibleItems {
    final trimmedQuery = searchQuery.trim().toLowerCase();

    final filtered = books.where((book) {
      final matchesFilter = switch (filter) {
        CatalogFilter.all => true,
        CatalogFilter.books => book.format != BookFormat.cbz,
        CatalogFilter.comics => book.format == BookFormat.cbz,
        CatalogFilter.saved => !book.isFinished,
        CatalogFilter.finished => book.isFinished,
      };
      if (!matchesFilter) return false;

      if (trimmedQuery.isEmpty) return true;
      final title = book.title.toLowerCase();
      final author = (book.author ?? '').toLowerCase();
      return title.contains(trimmedQuery) || author.contains(trimmedQuery);
    }).toList();

    filtered.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return filtered;
  }

  CatalogState copyWith({
    CatalogStatus? status,
    List<Book>? books,
    CatalogFilter? filter,
    String? searchQuery,
    int? deletionVersion,
  }) => CatalogState(
    status: status ?? this.status,
    books: books ?? this.books,
    filter: filter ?? this.filter,
    searchQuery: searchQuery ?? this.searchQuery,
    deletionVersion: deletionVersion ?? this.deletionVersion,
  );

  @override
  List<Object?> get props => [
    status,
    books,
    filter,
    searchQuery,
    deletionVersion,
  ];
}
