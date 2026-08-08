import 'dictionary_models.dart';

abstract interface class DictionaryLookupService {
  Future<DictionaryLookupResult> lookup(DictionaryLookupRequest request);

  void dispose();
}

abstract interface class SystemDictionaryService {
  /// Opens the platform definition UI and returns whether it was presented.
  Future<bool> showDefinition(String term);
}
