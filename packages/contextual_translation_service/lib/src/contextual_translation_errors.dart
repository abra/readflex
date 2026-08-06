enum ContextualTranslationFailureReason {
  network,
  http,
  invalidResponse,
  sourceLanguageRequired,
  offlineModelRequired,
  unsupportedLanguagePair,
  unavailable,
}

class ContextualTranslationException implements Exception {
  const ContextualTranslationException(
    this.reason,
    this.message, {
    this.statusCode,
    this.sourceLanguage,
    this.targetLanguage,
    this.cause,
  });

  final ContextualTranslationFailureReason reason;
  final String message;
  final int? statusCode;
  final String? sourceLanguage;
  final String? targetLanguage;
  final Object? cause;

  @override
  String toString() => 'ContextualTranslationException($reason, $message)';
}
