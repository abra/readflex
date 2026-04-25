import 'package:article_parser/article_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const sanitizer = ArticleHtmlSanitizer();

  group('ArticleHtmlSanitizer', () {
    test('strips <script> tags entirely', () {
      final input = '<p>Hello</p><script>alert(1)</script><p>World</p>';
      final output = sanitizer.sanitize(input);

      expect(output, isNot(contains('<script')));
      expect(output, isNot(contains('alert')));
      expect(output, contains('Hello'));
      expect(output, contains('World'));
    });

    test('drops inline event handlers', () {
      final input = '<img src="https://x/i.jpg" onerror="alert(1)">';
      final output = sanitizer.sanitize(input);

      expect(output, contains('<img'));
      expect(output, isNot(contains('onerror')));
      expect(output, isNot(contains('alert')));
    });

    test('drops javascript: URLs in <a href>', () {
      final input = '<a href="javascript:alert(1)">click</a>';
      final output = sanitizer.sanitize(input);

      expect(output, isNot(contains('javascript:')));
    });

    test('drops <iframe> tags', () {
      final input = '<p>Before</p><iframe src="https://evil"></iframe>';
      final output = sanitizer.sanitize(input);

      expect(output, isNot(contains('<iframe')));
      expect(output, contains('Before'));
    });

    test('drops <object> and <embed> tags', () {
      final input = '<object data="x"></object><embed src="x">';
      final output = sanitizer.sanitize(input);

      expect(output, isNot(contains('<object')));
      expect(output, isNot(contains('<embed')));
    });

    test('drops <style> tags (and CSS injection vector)', () {
      final input =
          '<style>body { background: url(javascript:alert(1)); }</style>';
      final output = sanitizer.sanitize(input);

      expect(output, isNot(contains('<style')));
      expect(output, isNot(contains('javascript:')));
    });

    test('keeps semantic tags + class attributes', () {
      final input =
          '<p class="lead">Body</p>'
          '<h2>Heading</h2>'
          '<blockquote>Quote</blockquote>'
          '<ul><li>One</li></ul>'
          '<pre><code>code</code></pre>';
      final output = sanitizer.sanitize(input);

      expect(output, contains('<p'));
      expect(output, contains('class="lead"'));
      expect(output, contains('<h2>'));
      expect(output, contains('<blockquote>'));
      expect(output, contains('<ul>'));
      expect(output, contains('<li>'));
      expect(output, contains('<pre>'));
      expect(output, contains('<code>'));
    });

    test('keeps <img> with safe http(s) src', () {
      final input = '<img src="https://example.com/img.jpg" alt="x">';
      final output = sanitizer.sanitize(input);

      expect(output, contains('<img'));
      expect(output, contains('src="https://example.com/img.jpg"'));
      expect(output, contains('alt="x"'));
    });

    test('adds rel=noopener noreferrer to <a> with href', () {
      final input = '<a href="https://example.com">link</a>';
      final output = sanitizer.sanitize(input);

      expect(output, contains('href="https://example.com"'));
      expect(output, contains('rel="noopener noreferrer"'));
    });

    test('keeps relative image references (used for offline images/)', () {
      // article_repository rewrites image src to relative paths; the
      // sanitizer must not strip those when we later switch to local
      // storage paths inside articles/<id>/.
      final input = '<img src="images/abc.jpg">';
      final output = sanitizer.sanitize(input);

      expect(output, contains('src="images/abc.jpg"'));
    });

    test('handles empty input', () {
      expect(sanitizer.sanitize(''), '');
    });
  });
}
