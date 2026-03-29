import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flashcard_repository/flashcard_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:highlight_repository/highlight_repository.dart';

import 'practice_bloc.dart';

enum MiniReviewStatus { loading, reviewing, empty, completed, failure }

class MiniReviewState {
  const MiniReviewState({
    this.status = MiniReviewStatus.loading,
    this.items = const [],
    this.currentIndex = 0,
    this.isRevealed = false,
  });

  final MiniReviewStatus status;
  final List<PracticeItem> items;
  final int currentIndex;
  final bool isRevealed;

  PracticeItem? get currentItem =>
      currentIndex < items.length ? items[currentIndex] : null;

  int get remaining => items.length - currentIndex;

  int get reviewed => currentIndex;

  MiniReviewState copyWith({
    MiniReviewStatus? status,
    List<PracticeItem>? items,
    int? currentIndex,
    bool? isRevealed,
  }) => MiniReviewState(
    status: status ?? this.status,
    items: items ?? this.items,
    currentIndex: currentIndex ?? this.currentIndex,
    isRevealed: isRevealed ?? this.isRevealed,
  );
}

class MiniReviewCubit extends Cubit<MiniReviewState> {
  MiniReviewCubit({
    required FlashcardRepository flashcardRepository,
    required HighlightRepository highlightRepository,
    required DictionaryRepository dictionaryRepository,
  }) : _flashcardRepository = flashcardRepository,
       _highlightRepository = highlightRepository,
       _dictionaryRepository = dictionaryRepository,
       super(const MiniReviewState());

  final FlashcardRepository _flashcardRepository;
  final HighlightRepository _highlightRepository;
  final DictionaryRepository _dictionaryRepository;

  Future<void> load(String sourceId) async {
    emit(state.copyWith(status: MiniReviewStatus.loading));

    try {
      final dueCards = await _flashcardRepository.getDueFlashcardsBySource(
        sourceId,
      );
      final dueHighlights = await _highlightRepository.getDueHighlightsBySource(
        sourceId,
      );
      final dueEntries = await _dictionaryRepository.getDueEntriesBySource(
        sourceId,
      );

      final items = <PracticeItem>[
        ...dueCards.map(PracticeItem.flashcard),
        ...dueHighlights.map(PracticeItem.highlight),
        ...dueEntries.map(PracticeItem.dictionary),
      ];

      if (items.isEmpty) {
        emit(state.copyWith(status: MiniReviewStatus.empty, items: []));
      } else {
        emit(
          state.copyWith(
            status: MiniReviewStatus.reviewing,
            items: items,
            currentIndex: 0,
            isRevealed: false,
          ),
        );
      }
    } catch (e) {
      emit(state.copyWith(status: MiniReviewStatus.failure));
    }
  }

  void reveal() {
    emit(state.copyWith(isRevealed: true));
  }

  Future<void> rate(Rating rating) async {
    final item = state.currentItem;
    if (item == null) return;

    try {
      switch (item) {
        case FlashcardItem(:final flashcard):
          await _flashcardRepository.recordReview(flashcard, rating);
        case HighlightItem(:final highlight):
          await _highlightRepository.recordReview(highlight, rating);
        case DictionaryItem(:final entry):
          await _dictionaryRepository.recordReview(entry, rating);
      }
      _advance();
    } catch (e) {
      emit(state.copyWith(status: MiniReviewStatus.failure));
    }
  }

  void _advance() {
    final nextIndex = state.currentIndex + 1;
    if (nextIndex >= state.items.length) {
      emit(state.copyWith(status: MiniReviewStatus.completed));
    } else {
      emit(state.copyWith(currentIndex: nextIndex, isRevealed: false));
    }
  }
}
