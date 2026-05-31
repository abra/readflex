import 'translation_service.dart';

/// Optional online translator/enricher.
///
/// The current app can use a direct client for development/internal testing,
/// but production should replace it with a backend-owned implementation so API
/// keys, rate limits, retries, and privacy policy are controlled server-side.
abstract interface class RemoteTranslationClient {
  Future<TranslationResult?> translate(
    String text, {
    required String fromLang,
    required String toLang,
    String? contextText,
  });

  Future<void> dispose();
}
