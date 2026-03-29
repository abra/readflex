import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:equatable/equatable.dart';
import 'package:flashcard_repository/flashcard_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:highlight_repository/highlight_repository.dart';

part 'practice_event.dart';
part 'practice_item.dart';
part 'practice_state.dart';

class PracticeBloc extends Bloc<PracticeEvent, PracticeState> {
  PracticeBloc({
    required FlashcardRepository flashcardRepository,
    required HighlightRepository highlightRepository,
    required DictionaryRepository dictionaryRepository,
  }) : _flashcardRepository = flashcardRepository,
       _highlightRepository = highlightRepository,
       _dictionaryRepository = dictionaryRepository,
       super(const PracticeState()) {
    on<PracticeLoadRequested>(_onLoadRequested);
    on<PracticeCardRated>(_onCardRated);
    on<PracticeCardRevealed>(_onCardRevealed);
    on<PracticeItemNext>(_onItemNext);
  }

  final FlashcardRepository _flashcardRepository;
  final HighlightRepository _highlightRepository;
  final DictionaryRepository _dictionaryRepository;

  Future<void> _onLoadRequested(
    PracticeLoadRequested event,
    Emitter<PracticeState> emit,
  ) async {
    emit(state.copyWith(status: PracticeStatus.loading));

    try {
      final dueCards = await _flashcardRepository.getDueFlashcards();
      final dueHighlights = await _highlightRepository.getDueHighlights();
      final dueEntries = await _dictionaryRepository.getDueEntries();

      final items = <PracticeItem>[
        ...dueCards.map(PracticeItem.flashcard),
        ...dueHighlights.map(PracticeItem.highlight),
        ...dueEntries.map(PracticeItem.dictionary),
      ];

      if (items.isEmpty) {
        emit(state.copyWith(status: PracticeStatus.empty, items: []));
      } else {
        emit(
          state.copyWith(
            status: PracticeStatus.reviewing,
            items: items,
            currentIndex: 0,
            isRevealed: false,
          ),
        );
      }
    } catch (e) {
      emit(state.copyWith(status: PracticeStatus.failure));
    }
  }

  void _onCardRevealed(
    PracticeCardRevealed event,
    Emitter<PracticeState> emit,
  ) {
    emit(state.copyWith(isRevealed: true));
  }

  Future<void> _onCardRated(
    PracticeCardRated event,
    Emitter<PracticeState> emit,
  ) async {
    final item = state.currentItem;
    if (item == null) return;

    try {
      switch (item) {
        case FlashcardItem(:final flashcard):
          await _flashcardRepository.recordReview(flashcard, event.rating);
        case HighlightItem(:final highlight):
          await _highlightRepository.recordReview(highlight, event.rating);
        case DictionaryItem(:final entry):
          await _dictionaryRepository.recordReview(entry, event.rating);
      }
      _advance(emit);
    } catch (e) {
      emit(state.copyWith(status: PracticeStatus.failure));
    }
  }

  void _onItemNext(
    PracticeItemNext event,
    Emitter<PracticeState> emit,
  ) {
    _advance(emit);
  }

  void _advance(Emitter<PracticeState> emit) {
    final nextIndex = state.currentIndex + 1;
    if (nextIndex >= state.items.length) {
      emit(state.copyWith(status: PracticeStatus.completed));
    } else {
      emit(state.copyWith(currentIndex: nextIndex, isRevealed: false));
    }
  }
}
