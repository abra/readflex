import 'package:article_parser/article_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NoopArticleParser', () {
    test('parse returns stub article with URL in content', () async {
      const parser = NoopArticleParser();
      final result = await parser.parse('https://example.com/article');
      expect(result.title, 'Stub Article');
      expect(result.cleanedHtml, contains('https://example.com/article'));
      expect(result.siteName, 'stub');
    });
  });
}
