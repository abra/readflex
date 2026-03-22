import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:shared/shared.dart';

class FakeDictionaryRepository implements DictionaryRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  final List<DictionaryEntry> _entries = [];
  bool shouldThrow = false;

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
    if (shouldThrow) throw StorageException(cause: 'fake');
    _entries.removeWhere((e) => e.id == id);
  }
}
