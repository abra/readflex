/// Thrown when the AI backend is unreachable or returns an error.
///
/// AI has no offline fallback — features surface this as "Unavailable
/// offline" in the UI.
class AiServiceException implements Exception {
  const AiServiceException(this.message);

  final String message;

  @override
  String toString() => 'AiServiceException: $message';
}

/// Contract for AI-backed content generation (hints, usage examples).
///
/// Implementations talk to Readflex's own backend, which in turn proxies
/// DeepSeek (or any swapped-in model). API keys stay server-side so the
/// model can change without an app update. No offline fallback — methods
/// throw [AiServiceException] when the backend is unreachable.
abstract class AiService {
  /// Generates a hint for a flashcard based on front/back text.
  Future<String> generateHint({required String front, required String back});

  /// Generates usage examples for a word/phrase in context.
  Future<List<String>> generateUsageExamples({
    required String text,
    String? context,
  });
}

/// Stub [AiService] that returns empty strings / lists without touching
/// the network. Used during development and in tests; swap for the real
/// HTTP client (→ own backend → DeepSeek) in `DependenciesContainer`.
class NoopAiService implements AiService {
  const NoopAiService();

  @override
  Future<String> generateHint({
    required String front,
    required String back,
  }) async => '';

  @override
  Future<List<String>> generateUsageExamples({
    required String text,
    String? context,
  }) async => const [];
}
