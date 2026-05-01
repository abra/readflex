import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fsrs_repository/fsrs_repository.dart';
import 'package:stream_transform/stream_transform.dart';

part 'dictionary_event.dart';
part 'dictionary_state.dart';

/// Backs the Dictionary tab ([DictionaryScreen]).
///
/// Loads saved [DictionaryEntry]s from [DictionaryRepository] on
/// [DictionaryLoadRequested] together with the set of mastered ids from
/// [FsrsRepository] for the "Mastered" badge. Handles debounced search
/// ([DictionarySearchChanged]) and entry removal
/// ([DictionaryEntryDeleted]) — deleting also drops the matching FSRS
/// review row.
class DictionaryBloc extends Bloc<DictionaryEvent, DictionaryState> {
  DictionaryBloc({
    required DictionaryRepository dictionaryRepository,
    required FsrsRepository fsrsRepository,
  }) : _repository = dictionaryRepository,
       _fsrsRepository = fsrsRepository,
       super(const DictionaryState()) {
    on<DictionaryLoadRequested>(_onLoadRequested);
    on<DictionarySearchChanged>(
      _onSearchChanged,
      transformer: _debounce(_searchDelay),
    );
    on<DictionaryFilterChanged>(_onFilterChanged);
    on<DictionaryEntryAdded>(_onEntryAdded);
    on<DictionaryEntryDeleted>(_onEntryDeleted);
    on<DictionaryEntriesDeleted>(_onEntriesDeleted);
  }

  final DictionaryRepository _repository;
  final FsrsRepository _fsrsRepository;

  static const _searchDelay = Duration(milliseconds: 300);

  static EventTransformer<E> _debounce<E>(Duration duration) {
    return (events, mapper) => events.debounce(duration).asyncExpand(mapper);
  }

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
    emit(state.copyWith(searchQuery: event.query));
  }

  void _onFilterChanged(
    DictionaryFilterChanged event,
    Emitter<DictionaryState> emit,
  ) {
    if (state.filter == event.filter) return;
    emit(state.copyWith(filter: event.filter));
  }

  Future<void> _onEntryAdded(
    DictionaryEntryAdded event,
    Emitter<DictionaryState> emit,
  ) async {
    try {
      await _repository.addEntry(
        word: event.word,
        translation: event.translation,
        pronunciation: event.pronunciation,
        partOfSpeech: event.partOfSpeech,
      );
      await _loadEntries(emit);
    } catch (e, st) {
      addError(e, st);
      emit(state.copyWith(status: DictionaryStatus.failure));
    }
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

  Future<void> _onEntriesDeleted(
    DictionaryEntriesDeleted event,
    Emitter<DictionaryState> emit,
  ) async {
    try {
      for (final id in event.entryIds) {
        await _repository.deleteEntry(id);
        await _fsrsRepository.deleteReviewItem(id);
      }
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
          masteredIds: masteredIds,
        ),
      );
    } catch (e, st) {
      addError(e, st);
      emit(state.copyWith(status: DictionaryStatus.failure));
    }
  }
}
