import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flashcard_repository/flashcard_repository.dart';
import 'package:highlight_repository/highlight_repository.dart';

import 'practice_item.dart';

/// Expands a list of FSRS [ReviewItem]s into a list of [PracticeItem]s the
/// review UI can render.
///
/// A [ReviewItem] carries only the type + id; the actual content (the
/// flashcard front/back, the highlighted sentence, the saved word) lives
/// in separate repositories. This resolver issues **one batch query per
/// type in parallel** rather than N sequential lookups, then zips the
/// results back together, preserving the FSRS due-order and silently
/// dropping any item whose underlying entity was deleted between
/// scheduling and resolution.
///
/// Pure, stateless, with no BLoC dependency — used by both `PracticeBloc`
/// (global review session) and `MiniReviewCubit` (in-reader mini session).
class PracticeItemResolver {
  const PracticeItemResolver({
    required FlashcardRepository flashcardRepository,
    required HighlightRepository highlightRepository,
    required DictionaryRepository dictionaryRepository,
  }) : _flashcardRepository = flashcardRepository,
       _highlightRepository = highlightRepository,
       _dictionaryRepository = dictionaryRepository;

  final FlashcardRepository _flashcardRepository;
  final HighlightRepository _highlightRepository;
  final DictionaryRepository _dictionaryRepository;

  /// Fetches and zips the backing entities for [dueItems]. Preserves the
  /// input order and drops items whose entity has been removed.
  Future<List<PracticeItem>> resolve(List<ReviewItem> dueItems) async {
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

    final resolved = <PracticeItem>[];
    for (final due in dueItems) {
      switch (due.itemType) {
        case ReviewableType.flashcard:
          if (cardMap[due.itemId] case final card?) {
            resolved.add(FlashcardItem(card));
          }
        case ReviewableType.highlight:
          if (hlMap[due.itemId] case final hl?) {
            resolved.add(HighlightItem(hl));
          }
        case ReviewableType.dictionary:
          if (entryMap[due.itemId] case final entry?) {
            resolved.add(DictionaryItem(entry));
          }
      }
    }
    return resolved;
  }
}
