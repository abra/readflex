import 'package:contextual_translation_service/contextual_translation_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('translationLanguagePrimaryCode', () {
    test('lowercases and drops region and script subtags', () {
      expect(translationLanguagePrimaryCode('EN'), 'en');
      expect(translationLanguagePrimaryCode('en-US'), 'en');
      expect(translationLanguagePrimaryCode('pt_BR'), 'pt');
      expect(translationLanguagePrimaryCode(' zh-Hans '), 'zh');
    });

    test('is null for missing or blank codes', () {
      expect(translationLanguagePrimaryCode(null), isNull);
      expect(translationLanguagePrimaryCode(''), isNull);
      expect(translationLanguagePrimaryCode('   '), isNull);
    });
  });

  group('isSameTranslationLanguage', () {
    test('matches one language written differently', () {
      expect(isSameTranslationLanguage('en', 'en'), isTrue);
      expect(isSameTranslationLanguage('en-GB', 'EN'), isTrue);
      expect(isSameTranslationLanguage('zh-Hant', 'zh'), isTrue);
    });

    test('different languages never match', () {
      expect(isSameTranslationLanguage('en', 'ru'), isFalse);
      expect(isSameTranslationLanguage('pt-BR', 'es'), isFalse);
    });

    test('an undetected or missing source never matches', () {
      expect(
        isSameTranslationLanguage(autoSourceLanguageCode, 'auto'),
        isFalse,
      );
      expect(isSameTranslationLanguage(null, null), isFalse);
      expect(isSameTranslationLanguage('', ''), isFalse);
      expect(isSameTranslationLanguage(null, 'en'), isFalse);
    });
  });
}
