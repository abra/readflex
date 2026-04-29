part of 'dictionary_bloc.dart';

/// Events accepted by [DictionaryBloc].
sealed class DictionaryEvent {
  const DictionaryEvent();
}

/// Initial (or retry) load of all saved dictionary entries.
final class DictionaryLoadRequested extends DictionaryEvent {
  const DictionaryLoadRequested();
}

/// Search-field input. Debounced before hitting the bloc handler.
final class DictionarySearchChanged extends DictionaryEvent {
  const DictionarySearchChanged(this.query);

  final String query;
}

/// Filter-chip selection above the list (All / Mastered / Learning /
/// Recent). Applied together with [DictionarySearchChanged.query].
final class DictionaryFilterChanged extends DictionaryEvent {
  const DictionaryFilterChanged(this.filter);

  final DictionaryFilter filter;
}

/// User-initiated delete of a dictionary entry; also removes its FSRS
/// review row.
final class DictionaryEntryDeleted extends DictionaryEvent {
  const DictionaryEntryDeleted(this.entryId);

  final String entryId;
}

/// Manual add-word submission from the [DictionaryAddWordSheet] form.
/// Persists the entry, then reloads the list so the new row shows up.
final class DictionaryEntryAdded extends DictionaryEvent {
  const DictionaryEntryAdded({
    required this.word,
    required this.translation,
    this.pronunciation,
    this.partOfSpeech,
  });

  final String word;
  final String translation;
  final String? pronunciation;
  final String? partOfSpeech;
}
