import 'package:domain_models/domain_models.dart';
import 'package:flashcard_repository/flashcard_repository.dart';

class FakeFlashcardRepository implements FlashcardRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  final Map<String, Flashcard> _cards = {};
  bool shouldThrow = false;

  void seed(List<Flashcard> cards) {
    _cards.clear();
    for (final c in cards) {
      _cards[c.id] = c;
    }
  }

  @override
  Future<Flashcard?> getFlashcardById(String id) async {
    if (shouldThrow) throw StorageException(cause: 'fake');
    return _cards[id];
  }

  @override
  Future<List<Flashcard>> getFlashcardsByIds(List<String> ids) async {
    if (shouldThrow) throw StorageException(cause: 'fake');
    return [for (final id in ids) ?_cards[id]];
  }
}
