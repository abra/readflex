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
/// into [StorageException]. The matching FSRS review row in
/// `review_items_table` is owned by `FsrsRepository` but co-deleted from
/// here in the same transaction so a deleted card never leaves an orphan
/// FSRS entry behind (which `getDueItems()` would surface forever).
class FlashcardRepository {
  FlashcardRepository({required AppDatabase database})
    : _db = database,
      _dao = database.flashcardsDao;

  final AppDatabase _db;
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

  /// Deletes the card and its FSRS review row in one transaction.
  /// Without the FSRS purge a deleted card stays in the review queue
  /// forever (the DAO returns any row whose `next_review_at` is due,
  /// regardless of whether the underlying entity still exists).
  Future<void> deleteFlashcard(String id) async {
    try {
      await _db.transaction(() async {
        await _db.reviewItemsDao.deleteItemsByIds([id]);
        await _dao.deleteFlashcard(id);
      });
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }
}
