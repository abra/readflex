part of 'library_bloc.dart';

enum LibraryStatus { initial, loading, success, failure }

/// What a collection scope narrows the Library to. One picker holds them all,
/// so there is a single way to choose what the Library shows.
enum LibraryCollectionScopeType {
  /// Built in, derived from the source: books that are not comics.
  books,

  /// Built in: saved articles.
  articles,

  /// Built in: comic archives.
  comics,

  /// Built in: never opened, the same rule as the cover's New badge.
  unread,

  /// Permanent, repository-managed membership.
  favourites,

  /// User-created, repository-managed membership.
  manual,

  /// Derived: articles grouped by site.
  site,

  /// Derived: sources grouped by author.
  author;

  /// Book, article, comic and New scopes, always built in this order.
  static const builtIn = [books, articles, comics, unread];

  bool get isBuiltIn => builtIn.contains(this);
}

class LibraryCollectionScope extends Equatable {
  LibraryCollectionScope.favourites({Iterable<String> sourceIds = const []})
    : type = LibraryCollectionScopeType.favourites,
      id = CollectionRepository.favouritesCollectionId,
      label = 'Favourites',
      sourceIds = _sortedUniqueSourceIds(sourceIds),
      sourceCount = sourceIds.toSet().length;

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

  bool get isBuiltIn => type.isBuiltIn;
  bool get isManual => type == LibraryCollectionScopeType.manual;
  bool get isFavourites => type == LibraryCollectionScopeType.favourites;
  bool get canManage => isManual || isFavourites;
  bool get canRename => isManual;
  bool get canDelete => isManual;

  @override
  List<Object?> get props => [type, id, label, sourceCount, sourceIds];
}

class LibraryDeletionEffect extends Equatable {
  const LibraryDeletionEffect({
    required this.version,
    required this.success,
    required this.sourceIds,
    this.singleTitle,
  });

  final int version;
  final bool success;

  /// Ids the finished delete covered, so a pending swipe can be matched to
  /// its own completion even when deletes overlap.
  final Set<String> sourceIds;
  final String? singleTitle;

  int get count => sourceIds.length;

  @override
  List<Object?> get props => [version, success, sourceIds, singleTitle];
}

class LibraryState extends Equatable {
  // Non-const because filtered/sorted lists are computed once per state.
  LibraryState({
    this.status = LibraryStatus.initial,
    this.sources = const [],
    this.collectionScopes = const [],
    this.collectionsLoadFailed = false,
    this.selectedCollectionScope,
    this.searchQuery = '',
    this.deletionVersion = 0,
    this.deletionEffect,
  });

  static const _absent = Object();

  final LibraryStatus status;
  final List<LibrarySource> sources;

  final List<LibraryCollectionScope> collectionScopes;
  final bool collectionsLoadFailed;
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

  /// Book, article, comic and New scopes in their fixed order.
  List<LibraryCollectionScope> get builtInCollectionScopes => collectionScopes
      .where((scope) => scope.isBuiltIn)
      .toList(growable: false);

  /// Built-in scopes the picker lists: empty ones and ones holding the whole
  /// library would only repeat Library, so they are left out unless
  /// selected — a selected scope that empties keeps its row to be left.
  List<LibraryCollectionScope> get pickerBuiltInCollectionScopes {
    final selected = selectedCollectionScope;
    return collectionScopes
        .where(
          (scope) =>
              scope.isBuiltIn &&
              ((scope.sourceCount > 0 && scope.sourceCount < totalCount) ||
                  (selected?.type == scope.type && selected?.id == scope.id)),
        )
        .toList(growable: false);
  }

  List<LibraryCollectionScope> get favouriteCollectionScopes => collectionScopes
      .where((scope) => scope.type == LibraryCollectionScopeType.favourites)
      .toList(growable: false);

  List<LibraryCollectionScope> get manualCollectionScopes => collectionScopes
      .where((scope) => scope.type == LibraryCollectionScopeType.manual)
      .toList(growable: false);

  List<LibraryCollectionScope> get siteCollectionScopes => collectionScopes
      .where((scope) => scope.type == LibraryCollectionScopeType.site)
      .toList(growable: false);

  List<LibraryCollectionScope> get authorCollectionScopes => collectionScopes
      .where((scope) => scope.type == LibraryCollectionScopeType.author)
      .toList(growable: false);

  /// Raw library size regardless of the collection scope; the Collections
  /// picker's Library row shows it.
  int get totalCount => sources.length;

  /// Size of the current scope (the whole library or the selected
  /// collection) shown under the header title. Ignores search.
  int get scopeItemCount => _collectionScopedSources.length;

  /// The unfiltered landing view: no search and no collection scope.
  bool get isDefaultView =>
      searchQuery.trim().isEmpty && selectedCollectionScope == null;

  /// Most recently opened source that is started but not finished, for the
  /// Library's Continue reading card; `null` when nothing qualifies.
  ///
  /// Cached per state like [visibleItems]; not in [props] for the same reason.
  late final LibrarySource? continueReadingSource =
      _computeContinueReadingSource(sources);

  late final List<LibrarySource> _collectionScopedSources =
      _applyCollectionScope(
        sources: sources,
        collectionScope: selectedCollectionScope,
      );

  static LibrarySource? _computeContinueReadingSource(
    List<LibrarySource> sources,
  ) {
    LibrarySource? latest;
    for (final source in sources) {
      final openedAt = source.lastOpenedAt;
      if (openedAt == null ||
          source.isFinished ||
          source.readingProgress <= 0 ||
          source.readingProgress >= 1) {
        continue;
      }
      if (latest == null || openedAt.isAfter(latest.lastOpenedAt!)) {
        latest = source;
      }
    }
    return latest;
  }

  /// Sources after applying the current collection scope and [searchQuery],
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
    sources: _collectionScopedSources,
    searchQuery: searchQuery,
  );

  static List<LibrarySource> _applyCollectionScope({
    required List<LibrarySource> sources,
    required LibraryCollectionScope? collectionScope,
  }) {
    if (collectionScope == null) return sources;
    return switch (collectionScope.type) {
      LibraryCollectionScopeType.books ||
      LibraryCollectionScopeType.articles ||
      LibraryCollectionScopeType.comics ||
      LibraryCollectionScopeType.unread =>
        sources
            .where(
              (source) => libraryBuiltInScopeMatches(
                collectionScope.type,
                source,
              ),
            )
            .toList(),
      // Favourite membership is repository-managed, but this remains a
      // permanent scope so it cannot be edited or deleted as manual collection.
      LibraryCollectionScopeType.favourites => _sourcesInCollection(
        sources,
        collectionScope,
      ),
      LibraryCollectionScopeType.manual => _sourcesInCollection(
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
                  _collectionScopeKey(_authorLabelForSource(source)) ==
                  collectionScope.id,
            )
            .toList(),
    };
  }

  static List<LibrarySource> _sourcesInCollection(
    List<LibrarySource> sources,
    LibraryCollectionScope collectionScope,
  ) {
    final sourceIds = collectionScope.sourceIds.toSet();
    return sources.where((source) => sourceIds.contains(source.id)).toList();
  }

  static List<LibrarySource> _computeVisibleItems({
    required List<LibrarySource> sources,
    required String searchQuery,
  }) {
    final trimmedQuery = searchQuery.trim().toLowerCase();

    final filtered = sources.where((source) {
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
    List<LibrarySource>? sources,
    List<LibraryCollectionScope>? collectionScopes,
    bool? collectionsLoadFailed,
    Object? selectedCollectionScope = _absent,
    String? searchQuery,
    int? deletionVersion,
    LibraryDeletionEffect? deletionEffect,
  }) => LibraryState(
    status: status ?? this.status,
    sources: sources ?? this.sources,
    collectionScopes: collectionScopes ?? this.collectionScopes,
    collectionsLoadFailed: collectionsLoadFailed ?? this.collectionsLoadFailed,
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
    sources,
    collectionScopes,
    collectionsLoadFailed,
    selectedCollectionScope,
    searchQuery,
    deletionVersion,
    deletionEffect,
  ];
}

/// Whether [source] belongs to the built-in scope [type]. The same predicate
/// builds the scope's count and narrows the list, so the two never disagree.
bool libraryBuiltInScopeMatches(
  LibraryCollectionScopeType type,
  LibrarySource source,
) {
  return switch (type) {
    LibraryCollectionScopeType.books =>
      source.sourceType == SourceType.book && !source.isComic,
    LibraryCollectionScopeType.articles =>
      source.sourceType == SourceType.article,
    LibraryCollectionScopeType.comics => source.isComic,
    // Same rule as the cover's New badge: never opened, nothing read.
    LibraryCollectionScopeType.unread => source.isNew,
    LibraryCollectionScopeType.favourites ||
    LibraryCollectionScopeType.manual ||
    LibraryCollectionScopeType.site ||
    LibraryCollectionScopeType.author => false,
  };
}

String? _siteLabelForSource(LibrarySource source) {
  if (source.sourceType != SourceType.article) return null;
  final sourceName = source.sourceName?.trim();
  if (sourceName != null && sourceName.isNotEmpty) return sourceName;
  return _siteDomainForSource(source);
}

String? _authorLabelForSource(LibrarySource source) {
  final author = source.author?.trim();
  if (author == null || author.isEmpty) return null;
  if (source.sourceType != SourceType.article) return author;
  final domain = _siteDomainForSource(source);
  if (domain == null || domain.isEmpty) return author;
  return '$author ($domain)';
}

String? _siteDomainForSource(LibrarySource source) {
  final originalUrl = source.originalUrl;
  if (originalUrl == null) return null;
  final host = Uri.tryParse(originalUrl)?.host.trim();
  if (host == null || host.isEmpty) return null;
  return host.startsWith('www.') ? host.substring(4) : host;
}

String _collectionScopeKey(String? value) => value?.trim().toLowerCase() ?? '';

List<String> _sortedUniqueSourceIds(Iterable<String> sourceIds) {
  final ids = sourceIds.toSet().toList()..sort();
  return List.unmodifiable(ids);
}
