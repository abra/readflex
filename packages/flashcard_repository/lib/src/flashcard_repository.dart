import 'package:domain_models/domain_models.dart';
import 'package:local_storage/local_storage.dart';
import 'package:uuid/uuid.dart' show Uuid;

import 'mappers/flashcard_to_domain.dart';
import 'mappers/flashcard_to_storage.dart';

// Top-level const so the Uuid generator is shared across all repository
// instances and allocated once at program start. `Uuid` is stateless for v4
// generation, so there's no benefit to holding it as an instance field.
const _uuid = Uuid();

/// Domain repository for flashcards.
///
/// Wraps [FlashcardsDao] from `local_storage` and turns low-level DB errors
/// into [StorageException]. FSRS review state is not stored here — that
/// lives in `FsrsRepository` and is joined by `itemId`.
class FlashcardRepository {
  FlashcardRepository({required AppDatabase database})
    : _dao = database.flashcardsDao;

  final FlashcardsDao _dao;

  // ─── CRUD ───

  Future<List<Flashcard>> getFlashcards() async {
    try {
      final rows = await _dao.allFlashcards();
      return rows.map((r) => r.toDomainModel()).toList();
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  Future<List<Flashcard>> getFlashcardsByDeck(String deckId) async {
    try {
      final rows = await _dao.flashcardsByDeck(deckId);
      return rows.map((r) => r.toDomainModel()).toList();
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  Future<Flashcard?> getFlashcardById(String id) async {
    try {
      final row = await _dao.flashcardById(id);
      return row?.toDomainModel();
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  Future<List<Flashcard>> getFlashcardsByIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    try {
      final rows = await _dao.flashcardsByIds(ids);
      return rows.map((r) => r.toDomainModel()).toList();
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  Future<Flashcard> addFlashcard({
    required String deckId,
    required String front,
    required String back,
    String? hint,
    String? sourceHighlightId,
    CreationSource creationSource = CreationSource.manual,
  }) async {
    try {
      final card = Flashcard(
        id: _uuid.v4(),
        deckId: deckId,
        front: front,
        back: back,
        hint: hint,
        sourceHighlightId: sourceHighlightId,
        creationSource: creationSource,
        createdAt: DateTime.now(),
      );
      await _dao.insertFlashcard(card.toStorageModel());
      return card;
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  Future<Flashcard> updateFlashcard(Flashcard card) async {
    try {
      await _dao.updateFlashcard(card.toStorageModel());
      return card;
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  Future<void> deleteFlashcard(String id) async {
    try {
      await _dao.deleteFlashcard(id);
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }
}
