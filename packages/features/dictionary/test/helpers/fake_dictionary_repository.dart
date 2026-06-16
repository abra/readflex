import 'dart:async';

import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:domain_models/domain_models.dart';

class FakeDictionaryRepository implements DictionaryRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  final List<DictionaryEntry> _entries = [];
  final _changes = StreamController<void>.broadcast(sync: true);
  bool shouldThrow = false;
  Set<String> failOnIds = const {};

  @override
  Stream<void> get changes => _changes.stream;

  void seed(List<DictionaryEntry> entries) => _entries
    ..clear()
    ..addAll(entries);

  @override
  Future<List<DictionaryEntry>> getEntries() async {
    if (shouldThrow) throw StorageException(cause: 'fake');
    return List.unmodifiable(_entries);
  }

  @override
  Future<void> deleteEntry(String id) async {
    if (shouldThrow || failOnIds.contains(id)) {
      throw StorageException(cause: 'fake');
    }
    _entries.removeWhere((e) => e.id == id);
    _notifyChanged();
  }

  @override
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
    if (shouldThrow) throw StorageException(cause: 'fake');
    final entry = DictionaryEntry(
      id: 'fake-${_entries.length + 1}',
      word: word,
      translation: translation,
      pronunciation: pronunciation,
      partOfSpeech: partOfSpeech,
      context: context,
      sourceId: sourceId,
      sourceType: sourceType,
      usageExamples: usageExamples,
      addedAt: addedAt ?? DateTime(2026),
    );
    _entries.add(entry);
    _notifyChanged();
    return entry;
  }

  void _notifyChanged() {
    if (!_changes.isClosed) _changes.add(null);
  }
}
