import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:domain_models/domain_models.dart';

class FakeDictionaryRepository implements DictionaryRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  final Map<String, DictionaryEntry> _entries = {};
  bool shouldThrow = false;

  void seed(List<DictionaryEntry> entries) {
    _entries.clear();
    for (final e in entries) {
      _entries[e.id] = e;
    }
  }

  @override
  Future<DictionaryEntry?> getEntryById(String id) async {
    if (shouldThrow) throw StorageException(cause: 'fake');
    return _entries[id];
  }

  @override
  Future<List<DictionaryEntry>> getEntriesByIds(List<String> ids) async {
    if (shouldThrow) throw StorageException(cause: 'fake');
    return [for (final id in ids) ?_entries[id]];
  }
}
