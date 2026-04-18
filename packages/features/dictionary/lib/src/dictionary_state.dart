part of 'dictionary_bloc.dart';

enum DictionaryStatus { initial, loading, success, failure }

class DictionaryState extends Equatable {
  const DictionaryState({
    this.status = DictionaryStatus.initial,
    this.entries = const [],
    this.searchQuery = '',
    this.masteredIds = const {},
  });

  final DictionaryStatus status;
  final List<DictionaryEntry> entries;
  final String searchQuery;

  /// IDs of entries that have reached FSRS "review" state (mastered).
  final Set<String> masteredIds;

  bool get isEmpty => entries.isEmpty;

  int get masteredCount => masteredIds.length;

  bool isMastered(String entryId) => masteredIds.contains(entryId);

  /// Filtered results derived from [entries] and [searchQuery]. Kept as a
  /// getter so the bloc doesn't need to recompute on every state transition.
  /// Callers should cache the result in a local variable to avoid repeated
  /// list allocation.
  List<DictionaryEntry> get filteredEntries {
    if (searchQuery.isEmpty) return entries;
    final q = searchQuery.toLowerCase();
    return [
      for (final e in entries)
        if (e.word.toLowerCase().contains(q) ||
            e.translation.toLowerCase().contains(q))
          e,
    ];
  }

  DictionaryState copyWith({
    DictionaryStatus? status,
    List<DictionaryEntry>? entries,
    String? searchQuery,
    Set<String>? masteredIds,
  }) => DictionaryState(
    status: status ?? this.status,
    entries: entries ?? this.entries,
    searchQuery: searchQuery ?? this.searchQuery,
    masteredIds: masteredIds ?? this.masteredIds,
  );

  @override
  List<Object?> get props => [status, entries, searchQuery, masteredIds];
}
