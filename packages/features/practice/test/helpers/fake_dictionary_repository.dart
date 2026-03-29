import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:domain_models/domain_models.dart';

class FakeDictionaryRepository implements DictionaryRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  List<DictionaryEntry> dueEntries = [];
  bool shouldThrow = false;

  @override
  Future<List<DictionaryEntry>> getDueEntries() async {
    if (shouldThrow) throw StorageException(cause: 'fake');
    return List.unmodifiable(dueEntries);
  }
}
