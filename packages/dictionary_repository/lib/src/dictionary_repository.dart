import 'package:domain_models/domain_models.dart';
import 'package:local_storage/local_storage.dart';
import 'package:review_scheduler/review_scheduler.dart';
import 'package:uuid/uuid.dart' show Uuid;

import 'mappers/entry_to_domain.dart';
import 'mappers/entry_to_storage.dart';
import 'mappers/review_log_to_storage.dart';

const _uuid = Uuid();

/// Domain repository for dictionary entries with FSRS v6 scheduling.
class DictionaryRepository {
  DictionaryRepository({
    required AppDatabase database,
    ReviewScheduler? reviewScheduler,
  }) : _dao = database.dictionaryDao,
       _reviewScheduler = reviewScheduler ?? ReviewScheduler();

  final DictionaryDao _dao;
  final ReviewScheduler _reviewScheduler;

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
    final result = _reviewScheduler.computeReview(
      itemId: entry.id,
      itemType: ReviewableType.dictionary,
      currentFsrs: entry.fsrs,
      rating: rating,
      reviewDurationMs: reviewDurationMs,
    );

    final updated = entry.copyWith(fsrs: result.fsrs);
    await _dao.updateEntry(updated.toStorageModel());
    await _dao.insertReviewLog(result.log.toStorageModel());

    return updated;
  }
}
