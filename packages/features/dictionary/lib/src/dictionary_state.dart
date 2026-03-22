part of 'dictionary_bloc.dart';

enum DictionaryStatus { initial, loading, success, failure }

final class DictionaryState extends Equatable {
  const DictionaryState({
    this.status = DictionaryStatus.initial,
    this.entries = const [],
    this.searchQuery = '',
  });

  final DictionaryStatus status;
  final List<DictionaryEntry> entries;
  final String searchQuery;

  List<DictionaryEntry> get filteredEntries {
    if (searchQuery.isEmpty) return entries;
    final query = searchQuery.toLowerCase();
    return entries
        .where(
          (e) =>
              e.word.toLowerCase().contains(query) ||
              e.translation.toLowerCase().contains(query),
        )
        .toList();
  }

  bool get isEmpty => entries.isEmpty;

  DictionaryState copyWith({
    DictionaryStatus? status,
    List<DictionaryEntry>? entries,
    String? searchQuery,
  }) => DictionaryState(
    status: status ?? this.status,
    entries: entries ?? this.entries,
    searchQuery: searchQuery ?? this.searchQuery,
  );

  @override
  List<Object?> get props => [status, entries, searchQuery];
}
