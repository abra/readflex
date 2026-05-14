import 'package:domain_models/domain_models.dart';
import 'package:local_storage/local_storage.dart';
import 'package:uuid/uuid.dart' show Uuid;

import 'mappers/entry_to_domain.dart';
import 'mappers/entry_to_storage.dart';

const _uuid = Uuid();

/// Domain repository for saved dictionary entries (words / phrases /
/// idioms).
///
/// Wraps [DictionaryDao] from `local_storage` and turns low-level DB errors
/// into [StorageException]. FSRS review state is not stored here — that
/// lives in `FsrsRepository` and is joined by `itemId`.
class DictionaryRepository {
  DictionaryRepository({required AppDatabase database})
    : _dao = database.dictionaryDao;

  final DictionaryDao _dao;

  // ─── CRUD ───

  Future<List<DictionaryEntry>> getEntries() async {
    try {
      final rows = await _dao.allEntries();
      return rows.map((r) => r.toDomainModel()).toList();
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  Future<List<DictionaryEntry>> getEntriesBySource(String sourceId) async {
    try {
      final rows = await _dao.entriesBySource(sourceId);
      return rows.map((r) => r.toDomainModel()).toList();
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  Future<int> getEntryCountBySource(String sourceId) async {
    try {
      return await _dao.entryCountBySource(sourceId);
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  Future<DictionaryEntry?> getEntryById(String id) async {
    try {
      final row = await _dao.entryById(id);
      return row?.toDomainModel();
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  Future<List<DictionaryEntry>> getEntriesByIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    try {
      final rows = await _dao.entriesByIds(ids);
      return rows.map((r) => r.toDomainModel()).toList();
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  Future<DictionaryEntry> addEntry({
    required String word,
    required String translation,
    String? pronunciation,
    String? partOfSpeech,
    String? context,
    String? sourceId,
    SourceType? sourceType,
    List<String> usageExamples = const [],
    DateTime? addedAt,
  }) async {
    try {
      final entry = DictionaryEntry(
        id: _uuid.v4(),
        word: word,
        translation: translation,
        pronunciation: pronunciation,
        partOfSpeech: partOfSpeech,
        context: context,
        sourceId: sourceId,
        sourceType: sourceType,
        usageExamples: usageExamples,
        addedAt: addedAt ?? DateTime.now(),
      );
      await _dao.insertEntry(entry.toStorageModel());
      return entry;
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  Future<DictionaryEntry> updateEntry(DictionaryEntry entry) async {
    try {
      await _dao.updateEntry(entry.toStorageModel());
      return entry;
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  Future<void> deleteEntry(String id) async {
    try {
      await _dao.deleteEntry(id);
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }
}
