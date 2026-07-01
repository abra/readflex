import 'package:flutter_test/flutter_test.dart';
import 'package:import_flow/src/article_url_utils.dart';

void main() {
  group('normalizeArticleUrl', () {
    test('rejects empty and whitespace input', () {
      expect(normalizeArticleUrl(''), isNull);
      expect(normalizeArticleUrl('   '), isNull);
      expect(normalizeArticleUrl('example .com'), isNull);
    });

    test('rejects single-label hosts with or without scheme', () {
      expect(normalizeArticleUrl('oifwoeifwoeiwoie'), isNull);
      expect(normalizeArticleUrl('https://oifwoeifwoeiwoie'), isNull);
    });

    test('normalizes valid article hosts without scheme', () {
      expect(
        normalizeArticleUrl('example.com/article'),
        'https://example.com/article',
      );
    });

    test('keeps valid article URLs with supported scheme', () {
      expect(
        normalizeArticleUrl('https://example.com/article'),
        'https://example.com/article',
      );
    });

    test('allows local development hosts', () {
      expect(
        normalizeArticleUrl('localhost:8080/article'),
        'https://localhost:8080/article',
      );
      expect(
        normalizeArticleUrl('http://127.0.0.1:8080/article'),
        'http://127.0.0.1:8080/article',
      );
    });
  });
}
