import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:equatable/equatable.dart';
import 'package:flashcard_repository/flashcard_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fsrs_repository/fsrs_repository.dart';
import 'package:highlight_repository/highlight_repository.dart';

import 'practice_bloc.dart';

part 'mini_review_state.dart';

class MiniReviewCubit extends Cubit<MiniReviewState> {
  MiniReviewCubit({
    required FsrsRepository fsrsRepository,
    required FlashcardRepository flashcardRepository,
    required HighlightRepository highlightRepository,
    required DictionaryRepository dictionaryRepository,
  }) : _fsrsRepository = fsrsRepository,
       _flashcardRepository = flashcardRepository,
       _highlightRepository = highlightRepository,
       _dictionaryRepository = dictionaryRepository,
       super(const MiniReviewState());

  final FsrsRepository _fsrsRepository;
  final FlashcardRepository _flashcardRepository;
  final HighlightRepository _highlightRepository;
  final DictionaryRepository _dictionaryRepository;

  Future<void> load(String sourceId) async {
    emit(state.copyWith(status: MiniReviewStatus.loading));

    try {
      final dueItems = await _fsrsRepository.getDueItemsBySource(sourceId);

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

      final items = <PracticeItem>[];
      for (final due in dueItems) {
        switch (due.itemType) {
          case ReviewableType.flashcard:
            if (cardMap[due.itemId] case final card?) {
              items.add(PracticeItem.flashcard(card));
            }
          case ReviewableType.highlight:
            if (hlMap[due.itemId] case final hl?) {
              items.add(PracticeItem.highlight(hl));
            }
          case ReviewableType.dictionary:
            if (entryMap[due.itemId] case final entry?) {
              items.add(PracticeItem.dictionary(entry));
            }
        }
      }

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
    } catch (e, st) {
      addError(e, st);
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
      await _fsrsRepository.recordReview(
        itemId: item.itemId,
        itemType: item.itemType,
        rating: rating,
      );
      _advance();
    } catch (e, st) {
      addError(e, st);
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
