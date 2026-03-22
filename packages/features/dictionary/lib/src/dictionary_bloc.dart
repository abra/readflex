import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared/shared.dart';

part 'dictionary_event.dart';
part 'dictionary_state.dart';

class DictionaryBloc extends Bloc<DictionaryEvent, DictionaryState> {
  DictionaryBloc({required DictionaryRepository dictionaryRepository})
    : _repository = dictionaryRepository,
      super(const DictionaryState()) {
    on<DictionaryLoadRequested>(_onLoadRequested);
    on<DictionarySearchChanged>(_onSearchChanged);
    on<DictionaryEntryDeleted>(_onEntryDeleted);
  }

  final DictionaryRepository _repository;

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

  Future<void> _onEntryDeleted(
    DictionaryEntryDeleted event,
    Emitter<DictionaryState> emit,
  ) async {
    try {
      await _repository.deleteEntry(event.entryId);
      await _loadEntries(emit);
    } catch (e) {
      emit(state.copyWith(status: DictionaryStatus.failure));
    }
  }

  Future<void> _loadEntries(Emitter<DictionaryState> emit) async {
    try {
      final entries = await _repository.getEntries();
      emit(
        state.copyWith(
          status: DictionaryStatus.success,
          entries: entries,
        ),
      );
    } catch (e) {
      emit(state.copyWith(status: DictionaryStatus.failure));
    }
  }
}
