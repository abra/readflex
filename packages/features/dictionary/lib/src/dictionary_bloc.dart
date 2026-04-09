import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fsrs_repository/fsrs_repository.dart';

part 'dictionary_event.dart';
part 'dictionary_state.dart';

class DictionaryBloc extends Bloc<DictionaryEvent, DictionaryState> {
  DictionaryBloc({
    required DictionaryRepository dictionaryRepository,
    required FsrsRepository fsrsRepository,
  }) : _repository = dictionaryRepository,
       _fsrsRepository = fsrsRepository,
       super(const DictionaryState()) {
    on<DictionaryLoadRequested>(_onLoadRequested);
    on<DictionarySearchChanged>(_onSearchChanged);
    on<DictionaryEntryDeleted>(_onEntryDeleted);
  }

  final DictionaryRepository _repository;
  final FsrsRepository _fsrsRepository;

  Future<void> _onLoadRequested(
    DictionaryLoadRequested event,
    Emitter<DictionaryState> emit,
  ) async {
    emit(state.copyWith(status: DictionaryStatus.loading));
    await _loadEntries(emit);
  }

  void _onSearchChanged(
    DictionarySearchChanged event,
    Emitter<DictionaryState> emit,
  ) {
    emit(
      state.copyWith(
        searchQuery: event.query,
        filteredEntries: _filter(state.entries, event.query),
      ),
    );
  }

  Future<void> _onEntryDeleted(
    DictionaryEntryDeleted event,
    Emitter<DictionaryState> emit,
  ) async {
    try {
      await _repository.deleteEntry(event.entryId);
      await _fsrsRepository.deleteReviewItem(event.entryId);
      await _loadEntries(emit);
    } catch (e, st) {
      addError(e, st);
      emit(state.copyWith(status: DictionaryStatus.failure));
    }
  }

  Future<void> _loadEntries(Emitter<DictionaryState> emit) async {
    try {
      final entries = await _repository.getEntries();
      final masteredIds = await _fsrsRepository.getMasteredItemIds(
        type: ReviewableType.dictionary,
      );
      emit(
        state.copyWith(
          status: DictionaryStatus.success,
          entries: entries,
          filteredEntries: _filter(entries, state.searchQuery),
          masteredIds: masteredIds,
        ),
      );
    } catch (e, st) {
      addError(e, st);
      emit(state.copyWith(status: DictionaryStatus.failure));
    }
  }

  static List<DictionaryEntry> _filter(
    List<DictionaryEntry> entries,
    String query,
  ) {
    if (query.isEmpty) return entries;
    final q = query.toLowerCase();
    return [
      for (final e in entries)
        if (e.word.toLowerCase().contains(q) ||
            e.translation.toLowerCase().contains(q))
          e,
    ];
  }
}
