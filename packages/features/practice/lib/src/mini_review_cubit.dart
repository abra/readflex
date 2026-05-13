import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:equatable/equatable.dart';
import 'package:flashcard_repository/flashcard_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fsrs_repository/fsrs_repository.dart';
import 'package:highlight_repository/highlight_repository.dart';

import 'practice_item.dart';
import 'practice_item_resolver.dart';

part 'mini_review_state.dart';

const _miniReviewDueLimit = 50;

/// Short in-reader review session scoped to a single source (book).
///
/// Mirrors [PracticeBloc]'s flow (load → reveal → rate → advance) but talks
/// to `fsrs_repository.getDueItemsBySource(sourceId)` so it only surfaces
/// items the user created while reading the current source. Uses the same
/// [PracticeItemResolver] as the main practice session so resolution logic
/// stays in one place.
class MiniReviewCubit extends Cubit<MiniReviewState> {
  MiniReviewCubit({
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
       super(const MiniReviewState());

  final FsrsRepository _fsrsRepository;
  final PracticeItemResolver _resolver;

  Future<void> load(String sourceId) async {
    emit(state.copyWith(status: MiniReviewStatus.loading));

    try {
      final dueItems = await _fsrsRepository.getDueItemsBySource(
        sourceId,
        limit: _miniReviewDueLimit,
      );
      final items = await _resolver.resolve(dueItems);

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
