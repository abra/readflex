import 'package:flashcard_repository/flashcard_repository.dart';
import 'package:domain_models/domain_models.dart';

class FakeFlashcardRepository implements FlashcardRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  List<Flashcard> dueCards = [];
  bool shouldThrow = false;

  @override
  Future<List<Flashcard>> getDueFlashcards() async {
    if (shouldThrow) throw StorageException(cause: 'fake');
    return dueCards;
  }
}
