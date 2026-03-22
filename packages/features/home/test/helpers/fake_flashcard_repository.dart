import 'package:flashcard_repository/flashcard_repository.dart';
import 'package:shared/shared.dart';

class FakeFlashcardRepository extends FlashcardRepository {
  List<Flashcard> dueCards = [];
  bool shouldThrow = false;

  @override
  Future<List<Flashcard>> getDueFlashcards() async {
    if (shouldThrow) throw StorageException(cause: 'fake');
    return dueCards;
  }
}
