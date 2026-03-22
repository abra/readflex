import 'package:drift/drift.dart';
import 'package:local_storage/local_storage.dart';
import 'package:shared/shared.dart';

extension FlashcardToStorage on Flashcard {
  FlashcardsTableCompanion toStorageModel() => FlashcardsTableCompanion(
    id: Value(id),
    deckId: Value(deckId),
    front: Value(front),
    back: Value(back),
    hint: Value(hint),
    sourceHighlightId: Value(sourceHighlightId),
    creationSource: Value(creationSource.name),
    createdAt: Value(createdAt.toIso8601String()),
    fsrsState: Value(fsrs.state.toStorageString()),
    stability: Value(fsrs.stability),
    difficulty: Value(fsrs.difficulty),
    retrievability: Value(fsrs.retrievability),
    reps: Value(fsrs.reps),
    lapses: Value(fsrs.lapses),
    lastReviewAt: Value(fsrs.lastReviewAt?.toIso8601String()),
    nextReviewAt: Value(fsrs.nextReviewAt?.toIso8601String()),
    scheduledDays: Value(fsrs.scheduledDays),
    elapsedDays: Value(fsrs.elapsedDays),
  );
}
