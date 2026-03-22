part of 'dictionary_bloc.dart';

sealed class DictionaryEvent {
  const DictionaryEvent();
}

final class DictionaryLoadRequested extends DictionaryEvent {
  const DictionaryLoadRequested();
}

final class DictionarySearchChanged extends DictionaryEvent {
  const DictionarySearchChanged(this.query);
  final String query;
}

final class DictionaryEntryDeleted extends DictionaryEvent {
  const DictionaryEntryDeleted(this.entryId);
  final String entryId;
}
