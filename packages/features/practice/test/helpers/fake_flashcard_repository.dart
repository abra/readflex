import 'package:flashcard_repository/flashcard_repository.dart';
import 'package:domain_models/domain_models.dart';

class FakeFlashcardRepository implements FlashcardRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  List<Flashcard> dueCards = [];
  bool shouldThrow = false;
  final List<({Flashcard card, Rating rating})> reviews = [];

  @override
  Future<List<Flashcard>> getDueFlashcards() async {
    if (shouldThrow) throw StorageException(cause: 'fake');
    return List.unmodifiable(dueCards);
  }

  @override
  Future<Flashcard> recordReview(
    Flashcard flashcard,
    Rating rating, {
    int? reviewDurationMs,
  }) async {
    if (shouldThrow) throw StorageException(cause: 'fake');
    reviews.add((card: flashcard, rating: rating));
    return flashcard;
  }
}
