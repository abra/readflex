import 'package:domain_models/domain_models.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:local_storage/local_storage.dart';
import 'package:uuid/uuid.dart' show Uuid;

import 'mappers/entry_to_domain.dart';
import 'mappers/entry_to_storage.dart';
import 'mappers/review_log_to_storage.dart';

const _uuid = Uuid();

/// Domain repository for dictionary entries with FSRS v6 scheduling.
class DictionaryRepository {
  DictionaryRepository({
    required AppDatabase database,
    fsrs.Scheduler? scheduler,
  }) : _dao = database.dictionaryDao,
       _scheduler = scheduler ?? fsrs.Scheduler();

  final DictionaryDao _dao;
  final fsrs.Scheduler _scheduler;

  // ─── CRUD ───

  Future<List<DictionaryEntry>> getEntries() async {
    final rows = await _dao.allEntries();
    return rows.map((r) => r.toDomainModel()).toList();
  }

  Future<List<DictionaryEntry>> getEntriesBySource(String sourceId) async {
    final rows = await _dao.entriesBySource(sourceId);
    return rows.map((r) => r.toDomainModel()).toList();
  }

  Future<List<DictionaryEntry>> getDueEntries() async {
    final now = DateTime.now().toUtc().toIso8601String();
    final rows = await _dao.dueEntries(now);
    return rows.map((r) => r.toDomainModel()).toList();
  }

  Future<List<DictionaryEntry>> getDueEntriesBySource(String sourceId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final rows = await _dao.dueEntriesBySource(sourceId, now);
    return rows.map((r) => r.toDomainModel()).toList();
  }

  Future<DictionaryEntry?> getEntryById(String id) async {
    final row = await _dao.entryById(id);
    return row?.toDomainModel();
  }

  Future<DictionaryEntry> addEntry({
    required String word,
    required String translation,
    String? context,
    String? sourceId,
    SourceType? sourceType,
    List<String> usageExamples = const [],
  }) async {
    final entry = DictionaryEntry(
      id: _uuid.v4(),
      word: word,
      translation: translation,
      context: context,
      sourceId: sourceId,
      sourceType: sourceType,
      usageExamples: usageExamples,
      addedAt: DateTime.now(),
    );
    await _dao.insertEntry(entry.toStorageModel());
    return entry;
  }

  Future<DictionaryEntry> updateEntry(DictionaryEntry entry) async {
    await _dao.updateEntry(entry.toStorageModel());
    return entry;
  }

  Future<void> deleteEntry(String id) async {
    await _dao.deleteEntry(id);
  }

  // ─── Review (FSRS) ───

  Future<DictionaryEntry> recordReview(
    DictionaryEntry entry,
    Rating rating, {
    int? reviewDurationMs,
  }) async {
    final now = DateTime.now().toUtc();
    final oldFsrs = entry.fsrs;

    final fsrsCard = fsrs.Card(cardId: entry.id.hashCode)
      ..state = _toFsrsState(oldFsrs.state)
      ..stability = oldFsrs.stability == 0.0 ? null : oldFsrs.stability
      ..difficulty = oldFsrs.difficulty == 0.0 ? null : oldFsrs.difficulty
      ..due = oldFsrs.nextReviewAt?.toUtc() ?? now
      ..lastReview = oldFsrs.lastReviewAt?.toUtc();

    final result = _scheduler.reviewCard(
      fsrsCard,
      _toFsrsRating(rating),
      reviewDateTime: now,
      reviewDuration: reviewDurationMs,
    );
    final updated = result.card;

    final elapsedDays = oldFsrs.lastReviewAt != null
        ? now.difference(oldFsrs.lastReviewAt!).inDays
        : 0;
    final scheduledDays = updated.due.difference(now).inDays;
    final retrievability = oldFsrs.state == FsrsState.review
        ? _scheduler.getCardRetrievability(fsrsCard)
        : 0.0;

    final newReps = oldFsrs.reps + 1;
    final newLapses =
        (rating == Rating.again && oldFsrs.state == FsrsState.review)
        ? oldFsrs.lapses + 1
        : oldFsrs.lapses;

    final updatedEntry = entry.copyWith(
      fsrs: FsrsCardData(
        state: _fromFsrsState(updated.state),
        stability: updated.stability ?? 0.0,
        difficulty: updated.difficulty ?? 0.0,
        retrievability: retrievability,
        reps: newReps,
        lapses: newLapses,
        lastReviewAt: now,
        nextReviewAt: updated.due,
        scheduledDays: scheduledDays,
        elapsedDays: elapsedDays,
      ),
    );

    final log = ReviewLog(
      id: _uuid.v4(),
      itemId: entry.id,
      itemType: ReviewableType.dictionary,
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

    await _dao.updateEntry(updatedEntry.toStorageModel());
    await _dao.insertReviewLog(log.toStorageModel());

    return updatedEntry;
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
