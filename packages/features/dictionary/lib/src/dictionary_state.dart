part of 'dictionary_bloc.dart';

enum DictionaryStatus { initial, loading, success, failure }

final class DictionaryState extends Equatable {
  const DictionaryState({
    this.status = DictionaryStatus.initial,
    this.entries = const [],
    this.filteredEntries = const [],
    this.searchQuery = '',
  });

  final DictionaryStatus status;
  final List<DictionaryEntry> entries;

  /// Pre-computed filtered results.
  final List<DictionaryEntry> filteredEntries;

  final String searchQuery;

  bool get isEmpty => entries.isEmpty;

  DictionaryState copyWith({
    DictionaryStatus? status,
    List<DictionaryEntry>? entries,
    List<DictionaryEntry>? filteredEntries,
    String? searchQuery,
  }) => DictionaryState(
    status: status ?? this.status,
    entries: entries ?? this.entries,
    filteredEntries: filteredEntries ?? this.filteredEntries,
    searchQuery: searchQuery ?? this.searchQuery,
  );

  @override
  List<Object?> get props => [status, entries, filteredEntries, searchQuery];
}
