import 'package:domain_models/domain_models.dart';
import 'package:local_storage/local_storage.dart';
import 'package:review_scheduler/review_scheduler.dart';
import 'package:uuid/uuid.dart' show Uuid;

import 'mappers/flashcard_to_domain.dart';
import 'mappers/flashcard_to_storage.dart';
import 'mappers/review_log_to_storage.dart';

const _uuid = Uuid();

/// Domain repository for flashcards with FSRS v6 scheduling.
class FlashcardRepository {
  FlashcardRepository({
    required AppDatabase database,
    ReviewScheduler? reviewScheduler,
  }) : _dao = database.flashcardsDao,
       _reviewScheduler = reviewScheduler ?? ReviewScheduler();

  final FlashcardsDao _dao;
  final ReviewScheduler _reviewScheduler;

  // ─── CRUD ───

  Future<List<Flashcard>> getFlashcards() async {
    final rows = await _dao.allFlashcards();
    return rows.map((r) => r.toDomainModel()).toList();
  }

  Future<List<Flashcard>> getFlashcardsByDeck(String deckId) async {
    final rows = await _dao.flashcardsByDeck(deckId);
    return rows.map((r) => r.toDomainModel()).toList();
  }

  Future<List<Flashcard>> getDueFlashcards() async {
    final now = DateTime.now().toUtc().toIso8601String();
    final rows = await _dao.dueFlashcards(now);
    return rows.map((r) => r.toDomainModel()).toList();
  }

  Future<List<Flashcard>> getDueFlashcardsBySource(String sourceId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final rows = await _dao.dueFlashcardsByDeck(sourceId, now);
    return rows.map((r) => r.toDomainModel()).toList();
  }

  Future<Flashcard?> getFlashcardById(String id) async {
    final row = await _dao.flashcardById(id);
    return row?.toDomainModel();
  }

  Future<Flashcard> addFlashcard({
    required String deckId,
    required String front,
    required String back,
    String? hint,
    String? sourceHighlightId,
    CreationSource creationSource = CreationSource.manual,
  }) async {
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
  }

  Future<Flashcard> updateFlashcard(Flashcard card) async {
    await _dao.updateFlashcard(card.toStorageModel());
    return card;
  }

  Future<void> deleteFlashcard(String id) async {
    await _dao.deleteFlashcard(id);
  }

  // ─── Review (FSRS) ───

  Future<Flashcard> recordReview(
    Flashcard flashcard,
    Rating rating, {
    int? reviewDurationMs,
  }) async {
    final result = _reviewScheduler.computeReview(
      itemId: flashcard.id,
      itemType: ReviewableType.flashcard,
      currentFsrs: flashcard.fsrs,
      rating: rating,
      reviewDurationMs: reviewDurationMs,
    );

    final updated = flashcard.copyWith(fsrs: result.fsrs);
    await _dao.updateFlashcard(updated.toStorageModel());
    await _dao.insertReviewLog(result.log.toStorageModel());

    return updated;
  }
}
