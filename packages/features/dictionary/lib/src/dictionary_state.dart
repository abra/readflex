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
  // Non-const because [filteredEntries] is a `late final` derived field
  // — const objects can't have late initializers. The trade-off is the
  // few `const DictionaryState(...)` literals in tests/bloc-init lose
  // their compile-time canonical form, which is irrelevant at runtime.
  DictionaryState({
    this.status = DictionaryStatus.initial,
    this.entries = const [],
    this.searchQuery = '',
    this.filter = DictionaryFilter.all,
    this.masteredIds = const {},
    this.deletionVersion = 0,
  });

  final DictionaryStatus status;
  final List<DictionaryEntry> entries;
  final String searchQuery;
  final DictionaryFilter filter;

  /// IDs of entries that have reached FSRS "review" state (mastered).
  final Set<String> masteredIds;

  /// Monotonic counter bumped exactly once per dispatched delete event
  /// (success OR failure). The screen pairs each delete with a queued
  /// descriptor and pops one off the queue every time the version
  /// changes; without this the screen-local "pending word" can be
  /// overwritten by a second swipe before the first finishes.
  final int deletionVersion;

  bool get isEmpty => entries.isEmpty;

  int get masteredCount => masteredIds.length;

  int get learningCount => entries.length - masteredIds.length;

  bool isMastered(String entryId) => masteredIds.contains(entryId);

  /// How many entries the "Recent" filter shows at most.
  static const int recentLimit = 5;

  /// Filtered results derived from [entries], [filter], and [searchQuery].
  ///
  /// Cached: `late final` evaluates [_compute] once per state instance
  /// and reuses the result. Earlier this was a getter that re-ran the
  /// filter + lowercase-search on every read — `BlocBuilder` reads it
  /// on every rebuild, so the same list was being computed dozens of
  /// times for one state.
  ///
  /// Filter is applied first, search second — that way "Recent" stays
  /// the newest matching entries even when the user types a query.
  ///
  /// Not in [props]: derived from already-compared fields, so two
  /// states with equal raw inputs already produce the same list.
  late final List<DictionaryEntry> filteredEntries = _compute(
    entries: entries,
    filter: filter,
    searchQuery: searchQuery,
    masteredIds: masteredIds,
  );

  static List<DictionaryEntry> _compute({
    required List<DictionaryEntry> entries,
    required DictionaryFilter filter,
    required String searchQuery,
    required Set<String> masteredIds,
  }) {
    final byFilter = _applyFilter(entries, filter, masteredIds);
    if (searchQuery.isEmpty) return byFilter;
    final q = searchQuery.toLowerCase();
    return [
      for (final e in byFilter)
        if (e.word.toLowerCase().contains(q) ||
            e.translation.toLowerCase().contains(q))
          e,
    ];
  }

  static List<DictionaryEntry> _applyFilter(
    List<DictionaryEntry> source,
    DictionaryFilter filter,
    Set<String> masteredIds,
  ) {
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
    int? deletionVersion,
  }) => DictionaryState(
    status: status ?? this.status,
    entries: entries ?? this.entries,
    searchQuery: searchQuery ?? this.searchQuery,
    filter: filter ?? this.filter,
    masteredIds: masteredIds ?? this.masteredIds,
    deletionVersion: deletionVersion ?? this.deletionVersion,
  );

  @override
  List<Object?> get props => [
    status,
    entries,
    searchQuery,
    filter,
    masteredIds,
    deletionVersion,
  ];
}
