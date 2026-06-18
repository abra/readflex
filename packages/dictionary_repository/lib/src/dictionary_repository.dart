import 'dart:async';

import 'package:domain_models/domain_models.dart';
import 'package:local_storage/local_storage.dart';
import 'package:uuid/uuid.dart' show Uuid;

import 'mappers/anchor_to_domain.dart';
import 'mappers/anchor_to_storage.dart';
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
    : _db = database,
      _dao = database.dictionaryDao;

  final AppDatabase _db;
  final DictionaryDao _dao;
  final _changes = StreamController<void>.broadcast(sync: true);

  /// Emits after a dictionary row is added, updated, or deleted.
  ///
  /// Feature blocs use this to stay fresh when another feature, such as the
  /// reader translate sheet, changes the dictionary through this repository.
  Stream<void> get changes => _changes.stream;

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

  Future<List<DictionaryAnchor>> getAnchorsBySource(String sourceId) async {
    try {
      final rows = await _dao.anchorsBySource(sourceId);
      return rows.map((r) => r.toDomainModel()).toList();
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  Future<List<DictionaryAnchor>> getAnchorsByEntry(String entryId) async {
    try {
      final rows = await _dao.anchorsByEntry(entryId);
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
    String? anchorText,
    String? anchorContext,
    String? anchorCfiRange,
    DictionaryAnchorKind? anchorKind,
  }) async {
    try {
      final now = addedAt ?? DateTime.now();
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
        addedAt: now,
      );
      final anchor = _anchorForEntry(
        entry: entry,
        sourceId: sourceId,
        sourceType: sourceType,
        text: anchorText,
        context: anchorContext,
        cfiRange: anchorCfiRange,
        kind: anchorKind,
        createdAt: now,
      );
      await _db.transaction(() async {
        await _dao.insertEntry(entry.toStorageModel());
        if (anchor != null) {
          await _dao.insertAnchor(anchor.toStorageModel());
        }
      });
      _notifyChanged();
      return entry;
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  Future<DictionaryAnchor> addAnchor({
    required String entryId,
    required String sourceId,
    required SourceType sourceType,
    required String text,
    required String cfiRange,
    String? context,
    DictionaryAnchorKind kind = DictionaryAnchorKind.exactSelection,
    DateTime? createdAt,
  }) async {
    try {
      final anchor = DictionaryAnchor(
        id: _uuid.v4(),
        entryId: entryId,
        sourceId: sourceId,
        sourceType: sourceType,
        text: text,
        context: _nonEmpty(context),
        cfiRange: cfiRange,
        kind: kind,
        createdAt: createdAt ?? DateTime.now(),
      );
      await _dao.insertAnchor(anchor.toStorageModel());
      _notifyChanged();
      return anchor;
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  Future<DictionaryEntry> updateEntry(DictionaryEntry entry) async {
    try {
      await _dao.updateEntry(entry.toStorageModel());
      _notifyChanged();
      return entry;
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  /// Deletes the entry and its FSRS review row in one transaction.
  /// Without the FSRS purge a deleted word can stay in the review queue
  /// because due-item queries are driven by `review_items_table`.
  Future<void> deleteEntry(String id) async {
    try {
      await _db.transaction(() async {
        await _db.reviewItemsDao.deleteItemsByIds([id]);
        await _dao.deleteEntry(id);
      });
      _notifyChanged();
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  Future<void> deleteAnchorsBySource(String sourceId) async {
    try {
      await _dao.deleteAnchorsBySource(sourceId);
      _notifyChanged();
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  Future<void> dispose() => _changes.close();

  void _notifyChanged() {
    if (!_changes.isClosed) _changes.add(null);
  }

  DictionaryAnchor? _anchorForEntry({
    required DictionaryEntry entry,
    required String? sourceId,
    required SourceType? sourceType,
    required String? text,
    required String? context,
    required String? cfiRange,
    required DictionaryAnchorKind? kind,
    required DateTime createdAt,
  }) {
    final normalizedSourceId = _nonEmpty(sourceId);
    final normalizedText = _nonEmpty(text);
    final normalizedCfiRange = _nonEmpty(cfiRange);
    if (normalizedSourceId == null ||
        sourceType == null ||
        normalizedText == null ||
        normalizedCfiRange == null) {
      return null;
    }
    return DictionaryAnchor(
      id: _uuid.v4(),
      entryId: entry.id,
      sourceId: normalizedSourceId,
      sourceType: sourceType,
      text: normalizedText,
      context: _nonEmpty(context),
      cfiRange: normalizedCfiRange,
      kind: kind ?? DictionaryAnchorKind.exactSelection,
      createdAt: createdAt,
    );
  }

  String? _nonEmpty(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
