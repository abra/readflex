import 'package:flutter_test/flutter_test.dart';
import 'package:translation_service/translation_service.dart';

void main() {
  group('NoopTranslationService', () {
    test('translate returns platform source with formatted text', () async {
      const service = NoopTranslationService();
      final result = await service.translate(
        'hello',
        fromLang: 'en',
        toLang: 'ru',
      );
      expect(result.originalText, 'hello');
      expect(result.translatedText, '[ru] hello');
      expect(result.source, TranslationSource.platform);
      expect(result.usageExamples, isEmpty);
    });
  });
}
