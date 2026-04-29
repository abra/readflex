part of 'dictionary_bloc.dart';

/// Load status of the dictionary screen.
enum DictionaryStatus { initial, loading, success, failure }

/// Filter chip applied above the dictionary list. Combined with
/// [DictionaryState.searchQuery] when computing
/// [DictionaryState.filteredEntries].
enum DictionaryFilter {
  /// Show every saved entry.
  all,

  /// Only entries the FSRS scheduler has graduated to "review" state.
  mastered,

  /// Entries still being learned (not yet mastered).
  learning,

  /// The most recently added entries (by [DictionaryEntry.addedAt]).
  recent,
}

/// State of the Dictionary tab: all saved entries, current search query,
/// active filter chip, and the ids of entries the FSRS scheduler treats
/// as mastered. The derived [filteredEntries] powers the list.
class DictionaryState extends Equatable {
  const DictionaryState({
    this.status = DictionaryStatus.initial,
    this.entries = const [],
    this.searchQuery = '',
    this.filter = DictionaryFilter.all,
    this.masteredIds = const {},
  });

  final DictionaryStatus status;
  final List<DictionaryEntry> entries;
  final String searchQuery;
  final DictionaryFilter filter;

  /// IDs of entries that have reached FSRS "review" state (mastered).
  final Set<String> masteredIds;

  bool get isEmpty => entries.isEmpty;

  int get masteredCount => masteredIds.length;

  int get learningCount => entries.length - masteredIds.length;

  bool isMastered(String entryId) => masteredIds.contains(entryId);

  /// How many entries the "Recent" filter shows at most.
  static const int recentLimit = 5;

  /// Filtered results derived from [entries], [filter], and [searchQuery].
  /// Kept as a getter so the bloc doesn't need to recompute on every state
  /// transition. Callers should cache the result in a local variable to
  /// avoid repeated list allocation.
  ///
  /// Filter is applied first, search second — that way "Recent" stays the
  /// newest matching entries even when the user types a query.
  List<DictionaryEntry> get filteredEntries {
    final byFilter = _applyFilter(entries);
    if (searchQuery.isEmpty) return byFilter;
    final q = searchQuery.toLowerCase();
    return [
      for (final e in byFilter)
        if (e.word.toLowerCase().contains(q) ||
            e.translation.toLowerCase().contains(q))
          e,
    ];
  }

  List<DictionaryEntry> _applyFilter(List<DictionaryEntry> source) {
    return switch (filter) {
      DictionaryFilter.all => source,
      DictionaryFilter.mastered => [
        for (final e in source)
          if (masteredIds.contains(e.id)) e,
      ],
      DictionaryFilter.learning => [
        for (final e in source)
          if (!masteredIds.contains(e.id)) e,
      ],
      DictionaryFilter.recent => () {
        final sorted = [...source]
          ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
        return sorted.take(recentLimit).toList(growable: false);
      }(),
    };
  }

  DictionaryState copyWith({
    DictionaryStatus? status,
    List<DictionaryEntry>? entries,
    String? searchQuery,
    DictionaryFilter? filter,
    Set<String>? masteredIds,
  }) => DictionaryState(
    status: status ?? this.status,
    entries: entries ?? this.entries,
    searchQuery: searchQuery ?? this.searchQuery,
    filter: filter ?? this.filter,
    masteredIds: masteredIds ?? this.masteredIds,
  );

  @override
  List<Object?> get props => [
    status,
    entries,
    searchQuery,
    filter,
    masteredIds,
  ];
}
