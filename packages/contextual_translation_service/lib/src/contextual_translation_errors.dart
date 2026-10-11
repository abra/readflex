enum ContextualTranslationFailureReason {
  cancelled,
  network,
  http,
  invalidResponse,
  sourceLanguageRequired,
  offlineModelRequired,
  unsupportedLanguagePair,
  unavailable,

  /// The text is already in the target language, so there is nothing to
  /// translate. Not a fault: [ContextualTranslationException.sourceLanguage]
  /// names that language, and no offline fallback runs.
  sameLanguage,
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
