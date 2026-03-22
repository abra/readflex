import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:local_storage/local_storage.dart';
import 'package:shared/shared.dart';
import 'package:uuid/uuid.dart' show Uuid;

import 'mappers/entry_to_domain.dart';
import 'mappers/entry_to_storage.dart';

const _uuid = Uuid();

/// Domain repository for dictionary entries.
class DictionaryRepository {
  DictionaryRepository({@visibleForTesting DictionaryDao? dictionaryDao})
    : _dao = dictionaryDao;

  DictionaryDao? _dao;

  void init(DictionaryDao dao) => _dao = dao;

  DictionaryDao get _dict {
    final dao = _dao;
    if (dao == null) {
      throw StateError(
        'DictionaryRepository not initialized. Call init() first.',
      );
    }
    return dao;
  }

  Future<List<DictionaryEntry>> getEntries() async {
    try {
      final rows = await _dict.allEntries();
      return rows.map((r) => r.toDomainModel()).toList();
    } catch (e) {
      throw StorageException(cause: e);
    }
  }

  Future<List<DictionaryEntry>> getEntriesBySource(String sourceId) async {
    try {
      final rows = await _dict.entriesBySource(sourceId);
      return rows.map((r) => r.toDomainModel()).toList();
    } catch (e) {
      throw StorageException(cause: e);
    }
  }

  Future<DictionaryEntry?> getEntryById(String id) async {
    try {
      final row = await _dict.entryById(id);
      return row?.toDomainModel();
    } catch (e) {
      throw StorageException(cause: e);
    }
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
    try {
      await _dict.insertEntry(entry.toStorageModel());
    } catch (e) {
      throw StorageException(cause: e);
    }
    return entry;
  }

  Future<DictionaryEntry> updateEntry(DictionaryEntry entry) async {
    try {
      await _dict.updateEntry(entry.toStorageModel());
    } catch (e) {
      throw StorageException(cause: e);
    }
    return entry;
  }

  Future<void> deleteEntry(String id) async {
    try {
      await _dict.deleteEntry(id);
    } catch (e) {
      throw StorageException(cause: e);
    }
  }
}
