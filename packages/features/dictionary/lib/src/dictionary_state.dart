part of 'dictionary_bloc.dart';

enum DictionaryStatus { initial, loading, success, failure }

class DictionaryState extends Equatable {
  const DictionaryState({
    this.status = DictionaryStatus.initial,
    this.entries = const [],
    this.filteredEntries = const [],
    this.searchQuery = '',
    this.masteredIds = const {},
  });

  final DictionaryStatus status;
  final List<DictionaryEntry> entries;

  /// Pre-computed filtered results.
  final List<DictionaryEntry> filteredEntries;

  final String searchQuery;

  /// IDs of entries that have reached FSRS "review" state (mastered).
  final Set<String> masteredIds;

  bool get isEmpty => entries.isEmpty;

  int get masteredCount => masteredIds.length;

  bool isMastered(String entryId) => masteredIds.contains(entryId);

  DictionaryState copyWith({
    DictionaryStatus? status,
    List<DictionaryEntry>? entries,
    List<DictionaryEntry>? filteredEntries,
    String? searchQuery,
    Set<String>? masteredIds,
  }) => DictionaryState(
    status: status ?? this.status,
    entries: entries ?? this.entries,
    filteredEntries: filteredEntries ?? this.filteredEntries,
    searchQuery: searchQuery ?? this.searchQuery,
    masteredIds: masteredIds ?? this.masteredIds,
  );

  @override
  List<Object?> get props => [
    status,
    entries,
    filteredEntries,
    searchQuery,
    masteredIds,
  ];
}
