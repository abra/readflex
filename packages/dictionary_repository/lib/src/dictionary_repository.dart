import 'package:domain_models/domain_models.dart';
import 'package:local_storage/local_storage.dart';
import 'package:uuid/uuid.dart' show Uuid;

import 'mappers/entry_to_domain.dart';
import 'mappers/entry_to_storage.dart';

const _uuid = Uuid();

/// Domain repository for dictionary entries.
class DictionaryRepository {
  DictionaryRepository({required AppDatabase database})
    : _dao = database.dictionaryDao;

  final DictionaryDao _dao;

  // ─── CRUD ───

  Future<List<DictionaryEntry>> getEntries() async {
    final rows = await _dao.allEntries();
    return rows.map((r) => r.toDomainModel()).toList();
  }

  Future<List<DictionaryEntry>> getEntriesBySource(String sourceId) async {
    final rows = await _dao.entriesBySource(sourceId);
    return rows.map((r) => r.toDomainModel()).toList();
  }

  Future<DictionaryEntry?> getEntryById(String id) async {
    final row = await _dao.entryById(id);
    return row?.toDomainModel();
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
  }

  Future<DictionaryEntry> updateEntry(DictionaryEntry entry) async {
    await _dao.updateEntry(entry.toStorageModel());
    return entry;
  }

  Future<void> deleteEntry(String id) async {
    await _dao.deleteEntry(id);
  }
}
