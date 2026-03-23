import 'package:flashcard_repository/flashcard_repository.dart';
import 'package:domain_models/domain_models.dart';

class FakeFlashcardRepository implements FlashcardRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  bool shouldThrow = false;

  final List<Flashcard> flashcards = [];

  @override
  Future<Flashcard> addFlashcard({
    required String deckId,
    required String front,
    required String back,
    String? hint,
    String? sourceHighlightId,
    CreationSource creationSource = CreationSource.manual,
  }) async {
    if (shouldThrow) throw Exception('addFlashcard failed');

    final card = Flashcard(
      id: 'fc-${flashcards.length + 1}',
      deckId: deckId,
      front: front,
      back: back,
      hint: hint,
      sourceHighlightId: sourceHighlightId,
      creationSource: creationSource,
      createdAt: DateTime.now(),
    );
    flashcards.add(card);
    return card;
  }
}
