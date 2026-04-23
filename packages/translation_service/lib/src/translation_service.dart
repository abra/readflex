import 'pronunciation/pronunciation.dart';

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

/// Translation + word-level pronunciation lookup.
///
/// [translate] is cross-language (text → translated text). [lookupPronunciation]
/// is monolingual (word → list of phonetic variants like IPA / pinyin). They
/// live on the same contract because they serve the same product flow — the
/// reader's "look up this text" bottom sheet — and share the same language
/// pack lifecycle (downloaded together per language).
///
/// Consumers get both through a single DI entry (`deps.translationService`);
/// implementations can back each method with a different data source (SQLite
/// for pronunciation, ML Kit / HTTP for translation) without leaking that
/// coupling to callers.
abstract class TranslationService {
  /// Translates [text] from [fromLang] to [toLang].
  Future<TranslationResult> translate(
    String text, {
    required String fromLang,
    required String toLang,
  });

  /// Returns all known pronunciation variants for [word] in [lang]. Empty
  /// list if the word is missing or the language dictionary isn't installed
  /// locally — callers decide whether to prompt a download or fall back to
  /// TTS / AI.
  Future<List<Pronunciation>> lookupPronunciation({
    required String word,
    required String lang,
  });

  /// Releases any open resources (database handles, caches). Safe to call
  /// repeatedly. Intended for shutdown / hot restart in development.
  Future<void> dispose();
}

/// Stub implementation — echoes the input as "translated" and returns empty
/// pronunciation results. Used for tests of unrelated code and as a safe
/// default until real backends are wired.
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

  @override
  Future<List<Pronunciation>> lookupPronunciation({
    required String word,
    required String lang,
  }) async => const [];

  @override
  Future<void> dispose() async {}
}
