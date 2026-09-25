import 'dictionary_models.dart';

abstract interface class DictionaryLookupService {
  /// Completing [abortTrigger] cancels this operation, not the shared client.
  Future<DictionaryLookupResult> lookup(
    DictionaryLookupRequest request, {
    Future<void>? abortTrigger,
  });

  void dispose();
}

abstract interface class SystemDictionaryService {
  /// Opens the platform definition UI and returns whether it was presented.
  Future<bool> showDefinition(String term);
}
