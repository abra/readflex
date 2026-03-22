import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:shared/shared.dart';

class FakeDictionaryRepository extends DictionaryRepository {
  bool shouldThrow = false;

  final List<DictionaryEntry> entries = [];

  @override
  Future<DictionaryEntry> addEntry({
    required String word,
    required String translation,
    String? context,
    String? sourceId,
    SourceType? sourceType,
    List<String> usageExamples = const [],
  }) async {
    if (shouldThrow) throw Exception('addEntry failed');

    final entry = DictionaryEntry(
      id: 'de-${entries.length + 1}',
      word: word,
      translation: translation,
      context: context,
      sourceId: sourceId,
      sourceType: sourceType,
      usageExamples: usageExamples,
      addedAt: DateTime.now(),
    );
    entries.add(entry);
    return entry;
  }
}
