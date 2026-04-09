import 'package:domain_models/domain_models.dart';
import 'package:local_storage/local_storage.dart';

final _epoch = DateTime.fromMillisecondsSinceEpoch(0);

extension FlashcardToDomain on FlashcardsTableData {
  Flashcard toDomainModel() => Flashcard(
    id: id,
    deckId: deckId,
    front: front,
    back: back,
    hint: hint,
    sourceHighlightId: sourceHighlightId,
    creationSource: CreationSource.from(creationSource),
    createdAt: DateTime.tryParse(createdAt) ?? _epoch,
  );
}
