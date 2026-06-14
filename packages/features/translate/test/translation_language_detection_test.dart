import 'package:flutter_test/flutter_test.dart';
import 'package:translate/src/translation_language_detection.dart';

void main() {
  group('detectTranslationSourceLanguage', () {
    test('detects Latin text as English', () {
      expect(detectTranslationSourceLanguage('hello'), 'en');
    });

    test('detects Cyrillic text as Russian', () {
      expect(detectTranslationSourceLanguage('привет'), 'ru');
    });

    test('uses context when selected text has no alphabetic signal', () {
      expect(
        detectTranslationSourceLanguage('...', contextText: 'Она сказала да.'),
        'ru',
      );
    });

    test('prefers selected text over surrounding context', () {
      expect(
        detectTranslationSourceLanguage(
          'hello',
          contextText: 'Она сказала hello.',
        ),
        'en',
      );
    });

    test('falls back when text has no supported alphabetic signal', () {
      expect(
        detectTranslationSourceLanguage('123', fallbackLanguageCode: 'ru'),
        'ru',
      );
    });
  });
}
