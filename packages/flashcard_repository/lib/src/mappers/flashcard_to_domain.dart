import 'package:domain_models/domain_models.dart';
import 'package:local_storage/local_storage.dart';

extension FlashcardToDomain on FlashcardsTableData {
  Flashcard toDomainModel() => Flashcard(
    id: id,
    deckId: deckId,
    front: front,
    back: back,
    hint: hint,
    sourceHighlightId: sourceHighlightId,
    creationSource: CreationSource.from(creationSource),
    createdAt: DateTime.parse(createdAt),
    fsrs: FsrsCardData(
      state: FsrsState.from(fsrsState),
      stability: stability,
      difficulty: difficulty,
      retrievability: retrievability,
      reps: reps,
      lapses: lapses,
      lastReviewAt: lastReviewAt != null ? DateTime.parse(lastReviewAt!) : null,
      nextReviewAt: nextReviewAt != null ? DateTime.parse(nextReviewAt!) : null,
      scheduledDays: scheduledDays,
      elapsedDays: elapsedDays,
    ),
  );
}
