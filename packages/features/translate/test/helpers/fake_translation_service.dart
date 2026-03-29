import 'package:translation_service/translation_service.dart';

class FakeTranslationService implements TranslationService {
  bool shouldThrow = false;
  TranslationResult? resultOverride;

  @override
  Future<TranslationResult> translate(
    String text, {
    required String fromLang,
    required String toLang,
  }) async {
    if (shouldThrow) throw const TranslationException('Translation failed');

    return resultOverride ??
        TranslationResult(
          originalText: text,
          translatedText: '[$toLang] $text',
          source: TranslationSource.platform,
        );
  }
}
