/// Thrown when AI service is unavailable (no network, backend error).
class AiServiceException implements Exception {
  const AiServiceException(this.message);
  final String message;

  @override
  String toString() => 'AiServiceException: $message';
}

/// HTTP client to own backend which calls DeepSeek API.
///
/// API keys stay on server, model swappable without app update.
/// No fallback — throws [AiServiceException] when unavailable.
abstract class AiService {
  /// Generates a hint for a flashcard based on front/back text.
  Future<String> generateHint({required String front, required String back});

  /// Generates usage examples for a word/phrase in context.
  Future<List<String>> generateUsageExamples({
    required String text,
    String? context,
  });
}

/// Stub that returns empty results. Used during development.
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
