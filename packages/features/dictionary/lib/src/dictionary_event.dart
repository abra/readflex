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

/// User-initiated delete of a dictionary entry; also removes its FSRS
/// review row.
final class DictionaryEntryDeleted extends DictionaryEvent {
  const DictionaryEntryDeleted(this.entryId);

  final String entryId;
}
