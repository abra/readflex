part of 'library_bloc.dart';

enum LibraryStatus { initial, loading, success, failure }

/// Filter segments mirrored from the readwell_demo Library screen. Kept
/// as an enum (not a string) so switches are exhaustive and renames are
/// refactor-safe.
enum LibraryFilter { all, books, articles, comics, unread }

enum LibraryCollectionScopeType { manual, site, author }

class LibraryCollectionScope extends Equatable {
  LibraryCollectionScope.manual({
    required LibraryCollection collection,
    required Iterable<String> sourceIds,
  }) : type = LibraryCollectionScopeType.manual,
       id = collection.id,
       label = collection.name,
       sourceIds = _sortedUniqueSourceIds(sourceIds),
       sourceCount = sourceIds.toSet().length;

  const LibraryCollectionScope.smart({
    required this.type,
    required this.id,
    required this.label,
    required this.sourceCount,
  }) : sourceIds = const [];

  final LibraryCollectionScopeType type;
  final String id;
  final String label;
  final int sourceCount;
  final List<String> sourceIds;

  bool get isManual => type == LibraryCollectionScopeType.manual;

  @override
  List<Object?> get props => [type, id, label, sourceCount, sourceIds];
}

class LibraryDeletionEffect extends Equatable {
  const LibraryDeletionEffect({
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

class LibraryState extends Equatable {
  // Non-const because [visibleItems] is a `late final` derived field —
  // const objects can't have late initializers. The trade-off is the
  // 8 `const LibraryState(...)` literals in tests/bloc-init lose their
  // compile-time canonical form, which is irrelevant at runtime.
  LibraryState({
    this.status = LibraryStatus.initial,
    this.books = const [],
    this.articles = const [],
    this.filter = LibraryFilter.all,
    this.collectionScopes = const [],
    this.selectedCollectionScope,
    this.searchQuery = '',
    this.deletionVersion = 0,
    this.deletionEffect,
  });

  static const _absent = Object();

  final LibraryStatus status;
  final List<Book> books;
  final List<Article> articles;

  late final List<LibrarySource> sources = [
    ...books.map(LibrarySource.fromBook),
    ...articles.map(LibrarySource.fromArticle),
  ];

  final LibraryFilter filter;
  final List<LibraryCollectionScope> collectionScopes;
  final LibraryCollectionScope? selectedCollectionScope;
  final String searchQuery;

  /// Monotonic counter bumped exactly once per dispatched delete event
  /// (success OR failure). Used as the identity of [deletionEffect] so
  /// listeners can distinguish consecutive delete completions.
  final int deletionVersion;

  /// One-shot UI effect emitted after a delete finishes. The screen listens
  /// for changes and renders the toast; it no longer owns delete queues.
  final LibraryDeletionEffect? deletionEffect;

  bool get isEmpty => sources.isEmpty;

  bool get hasCollectionScope => selectedCollectionScope != null;

  List<LibraryCollectionScope> get manualCollectionScopes => collectionScopes
      .where((scope) => scope.type == LibraryCollectionScopeType.manual)
      .toList(growable: false);

  List<LibraryCollectionScope> get siteCollectionScopes => collectionScopes
      .where((scope) => scope.type == LibraryCollectionScopeType.site)
      .toList(growable: false);

  List<LibraryCollectionScope> get authorCollectionScopes => collectionScopes
      .where((scope) => scope.type == LibraryCollectionScopeType.author)
      .toList(growable: false);

  /// Total count shown in the header ("N items") — reflects the raw
  /// library size regardless of the active filter or collection scope.
  int get totalCount => sources.length;

  late final List<LibrarySource> _collectionScopedSources =
      _applyCollectionScope(
        sources: sources,
        collectionScope: selectedCollectionScope,
      );

  /// Sources after applying the current collection scope, [filter], and
  /// [searchQuery], sorted by most-recently-opened first, then by newest added.
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
    sources: _collectionScopedSources,
    filter: filter,
    searchQuery: searchQuery,
  );

  static List<LibrarySource> _applyCollectionScope({
    required List<LibrarySource> sources,
    required LibraryCollectionScope? collectionScope,
  }) {
    if (collectionScope == null) return sources;
    return switch (collectionScope.type) {
      LibraryCollectionScopeType.manual => _sourcesInManualCollection(
        sources,
        collectionScope,
      ),
      LibraryCollectionScopeType.site =>
        sources
            .where(
              (source) =>
                  _collectionScopeKey(_siteLabelForSource(source)) ==
                  collectionScope.id,
            )
            .toList(),
      LibraryCollectionScopeType.author =>
        sources
            .where(
              (source) =>
                  _collectionScopeKey(source.author) == collectionScope.id,
            )
            .toList(),
    };
  }

  static List<LibrarySource> _sourcesInManualCollection(
    List<LibrarySource> sources,
    LibraryCollectionScope collectionScope,
  ) {
    final sourceIds = collectionScope.sourceIds.toSet();
    return sources.where((source) => sourceIds.contains(source.id)).toList();
  }

  static List<LibrarySource> _computeVisibleItems({
    required List<LibrarySource> sources,
    required LibraryFilter filter,
    required String searchQuery,
  }) {
    final trimmedQuery = searchQuery.trim().toLowerCase();

    final filtered = sources.where((source) {
      final matchesFilter = switch (filter) {
        LibraryFilter.all => true,
        LibraryFilter.books =>
          source.sourceType == SourceType.book && !source.isComic,
        LibraryFilter.articles => source.sourceType == SourceType.article,
        LibraryFilter.comics => source.isComic,
        LibraryFilter.unread => source.readingProgress == 0,
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

  LibraryState copyWith({
    LibraryStatus? status,
    List<Book>? books,
    List<Article>? articles,
    LibraryFilter? filter,
    List<LibraryCollectionScope>? collectionScopes,
    Object? selectedCollectionScope = _absent,
    String? searchQuery,
    int? deletionVersion,
    LibraryDeletionEffect? deletionEffect,
  }) => LibraryState(
    status: status ?? this.status,
    books: books ?? this.books,
    articles: articles ?? this.articles,
    filter: filter ?? this.filter,
    collectionScopes: collectionScopes ?? this.collectionScopes,
    selectedCollectionScope: selectedCollectionScope == _absent
        ? this.selectedCollectionScope
        : selectedCollectionScope as LibraryCollectionScope?,
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
    collectionScopes,
    selectedCollectionScope,
    searchQuery,
    deletionVersion,
    deletionEffect,
  ];
}

String? _siteLabelForSource(LibrarySource source) {
  if (source.sourceType != SourceType.article) return null;
  final sourceName = source.sourceName?.trim();
  if (sourceName != null && sourceName.isNotEmpty) return sourceName;
  final originalUrl = source.originalUrl;
  if (originalUrl == null) return null;
  final host = Uri.tryParse(originalUrl)?.host.trim();
  if (host == null || host.isEmpty) return null;
  return host;
}

String _collectionScopeKey(String? value) => value?.trim().toLowerCase() ?? '';

List<String> _sortedUniqueSourceIds(Iterable<String> sourceIds) {
  final ids = sourceIds.toSet().toList()..sort();
  return List.unmodifiable(ids);
}
