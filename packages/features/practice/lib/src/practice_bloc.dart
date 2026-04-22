import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:equatable/equatable.dart';
import 'package:flashcard_repository/flashcard_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fsrs_repository/fsrs_repository.dart';
import 'package:highlight_repository/highlight_repository.dart';

part 'practice_event.dart';
part 'practice_item.dart';
part 'practice_state.dart';

class PracticeBloc extends Bloc<PracticeEvent, PracticeState> {
  PracticeBloc({
    required FsrsRepository fsrsRepository,
    required FlashcardRepository flashcardRepository,
    required HighlightRepository highlightRepository,
    required DictionaryRepository dictionaryRepository,
  }) : _fsrsRepository = fsrsRepository,
       _flashcardRepository = flashcardRepository,
       _highlightRepository = highlightRepository,
       _dictionaryRepository = dictionaryRepository,
       super(const PracticeState()) {
    on<PracticeLoadRequested>(_onLoadRequested);
    on<PracticeCardRated>(_onCardRated);
    on<PracticeCardRevealed>(_onCardRevealed);
    on<PracticeItemNext>(_onItemNext);
  }

  final FsrsRepository _fsrsRepository;
  final FlashcardRepository _flashcardRepository;
  final HighlightRepository _highlightRepository;
  final DictionaryRepository _dictionaryRepository;

  Future<void> _onLoadRequested(
    PracticeLoadRequested event,
    Emitter<PracticeState> emit,
  ) async {
    emit(state.copyWith(status: PracticeStatus.loading));

    try {
      // A single session rarely goes past a few dozen cards; load a generous
      // slice instead of the whole due queue to avoid OOM on large decks.
      final dueItems = await _fsrsRepository.getDueItems(limit: 50);
      final items = await _resolveItems(dueItems);

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

  /// Resolves ReviewItems into PracticeItems by fetching the actual entities
  /// in parallel batch queries instead of sequential per-item lookups.
  Future<List<PracticeItem>> _resolveItems(List<ReviewItem> dueItems) async {
    final flashcardIds = <String>[];
    final highlightIds = <String>[];
    final dictionaryIds = <String>[];

    for (final due in dueItems) {
      switch (due.itemType) {
        case ReviewableType.flashcard:
          flashcardIds.add(due.itemId);
        case ReviewableType.highlight:
          highlightIds.add(due.itemId);
        case ReviewableType.dictionary:
          dictionaryIds.add(due.itemId);
      }
    }

    final (cards, highlights, entries) = await (
      _flashcardRepository.getFlashcardsByIds(flashcardIds),
      _highlightRepository.getHighlightsByIds(highlightIds),
      _dictionaryRepository.getEntriesByIds(dictionaryIds),
    ).wait;

    final cardMap = {for (final c in cards) c.id: c};
    final hlMap = {for (final h in highlights) h.id: h};
    final entryMap = {for (final e in entries) e.id: e};

    // Preserve original order from dueItems, skip items deleted between
    // scheduling and resolution.
    final items = <PracticeItem>[];
    for (final due in dueItems) {
      switch (due.itemType) {
        case ReviewableType.flashcard:
          if (cardMap[due.itemId] case final card?) {
            items.add(FlashcardItem(card));
          }
        case ReviewableType.highlight:
          if (hlMap[due.itemId] case final hl?) {
            items.add(HighlightItem(hl));
          }
        case ReviewableType.dictionary:
          if (entryMap[due.itemId] case final entry?) {
            items.add(DictionaryItem(entry));
          }
      }
    }
    return items;
  }
}
