import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:equatable/equatable.dart';
import 'package:flashcard_repository/flashcard_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fsrs_repository/fsrs_repository.dart';
import 'package:highlight_repository/highlight_repository.dart';

import 'practice_item.dart';
import 'practice_item_resolver.dart';

part 'practice_event.dart';
part 'practice_state.dart';

/// Global practice session — drives the Practice tab.
///
/// Responsibility is narrow: load all currently-due review items from FSRS,
/// expand them into display-ready [PracticeItem]s via [PracticeItemResolver],
/// track revealed/current index, and record the user's rating back into FSRS.
/// The merging of FSRS ids → domain entities lives in the resolver, not here.
class PracticeBloc extends Bloc<PracticeEvent, PracticeState> {
  PracticeBloc({
    required FsrsRepository fsrsRepository,
    required FlashcardRepository flashcardRepository,
    required HighlightRepository highlightRepository,
    required DictionaryRepository dictionaryRepository,
  }) : _fsrsRepository = fsrsRepository,
       _resolver = PracticeItemResolver(
         flashcardRepository: flashcardRepository,
         highlightRepository: highlightRepository,
         dictionaryRepository: dictionaryRepository,
       ),
       super(const PracticeState()) {
    on<PracticeLoadRequested>(_onLoadRequested);
    on<PracticeCardRated>(_onCardRated);
    on<PracticeCardRevealed>(_onCardRevealed);
    on<PracticeItemNext>(_onItemNext);
  }

  final FsrsRepository _fsrsRepository;
  final PracticeItemResolver _resolver;

  Future<void> _onLoadRequested(
    PracticeLoadRequested event,
    Emitter<PracticeState> emit,
  ) async {
    emit(state.copyWith(status: PracticeStatus.loading));

    try {
      // A single session rarely goes past a few dozen cards; load a generous
      // slice instead of the whole due queue to avoid OOM on large decks.
      final dueItems = await _fsrsRepository.getDueItems(limit: 50);
      final items = await _resolver.resolve(dueItems);

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
    } catch (e, st) {
      addError(e, st);
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
      await _fsrsRepository.recordReview(
        itemId: item.itemId,
        itemType: item.itemType,
        rating: event.rating,
      );
      _advance(emit);
    } catch (e, st) {
      addError(e, st);
      emit(state.copyWith(status: PracticeStatus.failure));
    }
  }

  void _onItemNext(PracticeItemNext event, Emitter<PracticeState> emit) {
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
