/// Source of translation result.
enum TranslationSource { remote, platform }

/// Result of a translation request.
class TranslationResult {
  const TranslationResult({
    required this.originalText,
    required this.translatedText,
    required this.source,
    this.context,
    this.usageExamples = const [],
  });

  final String originalText;
  final String translatedText;
  final TranslationSource source;

  /// AI-enriched context (premium, remote only).
  final String? context;

  /// AI-generated usage examples (premium, remote only).
  final List<String> usageExamples;
}

/// Thrown when translation fails on both remote and platform.
class TranslationException implements Exception {
  const TranslationException(this.message);

  final String message;

  @override
  String toString() => 'TranslationException: $message';
}

/// Translation service with remote → platform fallback strategy.
///
/// Feature code calls [translate()] without knowing about network state.
/// [TranslationResult.source] tells the UI whether to show AI-enriched blocks.
abstract class TranslationService {
  /// Translates [text] from [fromLang] to [toLang].
  Future<TranslationResult> translate(
    String text, {
    required String fromLang,
    required String toLang,
  });
}

/// Stub implementation that echoes the input as "translated".
class NoopTranslationService implements TranslationService {
  const NoopTranslationService();

  @override
  Future<TranslationResult> translate(
    String text, {
    required String fromLang,
    required String toLang,
  }) async => TranslationResult(
    originalText: text,
    translatedText: '[$toLang] $text',
    source: TranslationSource.platform,
  );
}
