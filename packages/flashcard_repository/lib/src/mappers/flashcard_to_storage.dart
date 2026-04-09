import 'package:domain_models/domain_models.dart';
import 'package:drift/drift.dart';
import 'package:local_storage/local_storage.dart';

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
  );
}
