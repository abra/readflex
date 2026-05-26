import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('article text direction', () {
    test('normalizes language tags', () {
      expect(normalizeArticleLanguage('ar_EG'), 'ar-eg');
      expect(normalizeArticleLanguage(' ar, en;q=0.9 '), 'ar');
      expect(normalizeArticleLanguage('x-default'), isNull);
    });

    test('detects rtl languages and scripts', () {
      expect(articleTextDirectionForLanguage('ar'), ArticleTextDirection.rtl);
      expect(
        articleTextDirectionForLanguage('ar-EG'),
        ArticleTextDirection.rtl,
      );
      expect(
        articleTextDirectionForLanguage('az-Arab'),
        ArticleTextDirection.rtl,
      );
      expect(articleTextDirectionForLanguage('en'), isNull);
    });

    test('infers direction from text sample', () {
      expect(
        inferArticleTextDirectionFromText('مرحبا هذا نص عربي طويل'),
        ArticleTextDirection.rtl,
      );
      expect(
        inferArticleTextDirectionFromText('This is a readable article'),
        ArticleTextDirection.ltr,
      );
    });
  });
}
