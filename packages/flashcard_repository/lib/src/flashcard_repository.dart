import 'package:domain_models/domain_models.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:local_storage/local_storage.dart';
import 'package:uuid/uuid.dart' show Uuid;

import 'mappers/flashcard_to_domain.dart';
import 'mappers/flashcard_to_storage.dart';
import 'mappers/review_log_to_storage.dart';

const _uuid = Uuid();

/// Domain repository for flashcards with FSRS v6 scheduling.
class FlashcardRepository {
  FlashcardRepository({
    required AppDatabase database,
    fsrs.Scheduler? scheduler,
  }) : _dao = database.flashcardsDao,
       _scheduler = scheduler ?? fsrs.Scheduler();

  final FlashcardsDao _dao;
  final fsrs.Scheduler _scheduler;

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

  /// Records a review using FSRS v6 scheduling.
  ///
  /// Updates the flashcard's FSRS data and saves a review log.
  /// Returns the updated flashcard.
  Future<Flashcard> recordReview(
    Flashcard flashcard,
    Rating rating, {
    int? reviewDurationMs,
  }) async {
    final now = DateTime.now().toUtc();
    final oldFsrs = flashcard.fsrs;

    // Map domain → fsrs package types
    final fsrsCard = fsrs.Card(cardId: flashcard.id.hashCode)
      ..state = _toFsrsState(oldFsrs.state)
      ..stability = oldFsrs.stability == 0.0 ? null : oldFsrs.stability
      ..difficulty = oldFsrs.difficulty == 0.0 ? null : oldFsrs.difficulty
      ..due = oldFsrs.nextReviewAt?.toUtc() ?? now
      ..lastReview = oldFsrs.lastReviewAt?.toUtc();

    final fsrsRating = _toFsrsRating(rating);

    // Run FSRS scheduling
    final result = _scheduler.reviewCard(
      fsrsCard,
      fsrsRating,
      reviewDateTime: now,
      reviewDuration: reviewDurationMs,
    );
    final updatedFsrsCard = result.card;

    // Compute elapsed/scheduled days
    final elapsedDays = oldFsrs.lastReviewAt != null
        ? now.difference(oldFsrs.lastReviewAt!).inDays
        : 0;
    final scheduledDays = updatedFsrsCard.due.difference(now).inDays;

    // Compute retrievability
    final retrievability = oldFsrs.state == FsrsState.review
        ? _scheduler.getCardRetrievability(fsrsCard)
        : 0.0;

    // Build updated domain flashcard
    final newReps = oldFsrs.reps + 1;
    final newLapses =
        (rating == Rating.again && oldFsrs.state == FsrsState.review)
        ? oldFsrs.lapses + 1
        : oldFsrs.lapses;

    final updatedFlashcard = flashcard.copyWith(
      fsrs: FsrsCardData(
        state: _fromFsrsState(updatedFsrsCard.state),
        stability: updatedFsrsCard.stability ?? 0.0,
        difficulty: updatedFsrsCard.difficulty ?? 0.0,
        retrievability: retrievability,
        reps: newReps,
        lapses: newLapses,
        lastReviewAt: now,
        nextReviewAt: updatedFsrsCard.due,
        scheduledDays: scheduledDays,
        elapsedDays: elapsedDays,
      ),
    );

    // Build review log
    final log = ReviewLog(
      id: _uuid.v4(),
      itemId: flashcard.id,
      itemType: ReviewableType.flashcard,
      rating: rating,
      stateBefore: oldFsrs.state,
      stabilityBefore: oldFsrs.stability,
      difficultyBefore: oldFsrs.difficulty,
      retrievabilityAtReview: retrievability,
      scheduledDays: scheduledDays,
      elapsedDays: elapsedDays,
      reviewDurationMs: reviewDurationMs,
      reviewedAt: now,
    );

    await _dao.updateFlashcard(updatedFlashcard.toStorageModel());
    await _dao.insertReviewLog(log.toStorageModel());

    return updatedFlashcard;
  }

  // ─── Mapping helpers ───

  static fsrs.State _toFsrsState(FsrsState state) => switch (state) {
    FsrsState.newCard => fsrs.State.learning,
    FsrsState.learning => fsrs.State.learning,
    FsrsState.review => fsrs.State.review,
    FsrsState.relearning => fsrs.State.relearning,
  };

  static FsrsState _fromFsrsState(fsrs.State state) => switch (state) {
    fsrs.State.learning => FsrsState.learning,
    fsrs.State.review => FsrsState.review,
    fsrs.State.relearning => FsrsState.relearning,
  };

  static fsrs.Rating _toFsrsRating(Rating rating) => switch (rating) {
    Rating.again => fsrs.Rating.again,
    Rating.hard => fsrs.Rating.hard,
    Rating.good => fsrs.Rating.good,
    Rating.easy => fsrs.Rating.easy,
  };
}
