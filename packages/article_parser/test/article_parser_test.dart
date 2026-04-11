import 'package:article_parser/article_parser.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

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

  group('ReadabilityArticleParser', () {
    // Minimal but realistic article HTML: enough paragraphs for readability
    // to accept it as an article, includes Open Graph metadata for siteName,
    // byline via meta author, and an image for cover extraction.
    const articleHtml = '''
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Test Article Title</title>
<meta property="og:site_name" content="Example Daily">
<meta name="author" content="Jane Writer">
<meta name="description" content="A short article description.">
</head>
<body>
<header><nav>Site Navigation</nav></header>
<article>
<h1>Test Article Title</h1>
<p>By Jane Writer, published today.</p>
<p>This is the first paragraph of the article. It is long enough to pass
the readability length threshold and contains multiple sentences about a
topic. The content is substantial and carries real meaning for the reader.</p>
<p>The second paragraph continues with more detail. It discusses related
points, expands on the thesis, and provides additional context. Readers
who have made it this far are genuinely engaged with the material.</p>
<p>A third paragraph keeps the article from looking like a stub. It adds
another layer of discussion, references prior work, and points to what
comes next. This is enough for the extractor to be confident.</p>
<figure>
<img src="https://cdn.example.com/cover.jpg" alt="Cover">
</figure>
<p>A closing paragraph summarises the piece. It draws conclusions from
the earlier sections and invites the reader to think further about what
was presented.</p>
</article>
<footer>Site Footer</footer>
</body>
</html>
''';

    test('parse extracts title, byline, siteName, cover and content', () async {
      final client = MockClient((request) async {
        return http.Response(
          articleHtml,
          200,
          headers: const {'content-type': 'text/html; charset=utf-8'},
        );
      });
      final parser = ReadabilityArticleParser(httpClient: client);

      final result = await parser.parse('https://example.com/story');

      expect(result.title, contains('Test Article Title'));
      expect(result.cleanedHtml, contains('first paragraph'));
      expect(result.cleanedHtml, isNot(contains('Site Navigation')));
      expect(result.cleanedHtml, isNot(contains('Site Footer')));
      expect(result.siteName, 'Example Daily');
      expect(result.byline, contains('Jane Writer'));
      expect(result.coverImageUrl, 'https://cdn.example.com/cover.jpg');
      expect(result.lang, 'en');
      expect(result.estimatedWordCount, greaterThan(30));
      expect(result.textLength, greaterThan(100));
    });

    test('parse throws invalidUrl for garbage input', () async {
      final parser = ReadabilityArticleParser(
        httpClient: MockClient((_) async => http.Response('', 200)),
      );

      await expectLater(
        parser.parse('not a url'),
        throwsA(
          isA<ArticleParserException>().having(
            (e) => e.reason,
            'reason',
            ArticleParserFailure.invalidUrl,
          ),
        ),
      );
    });

    test('parse throws httpStatus with statusCode on non-200', () async {
      final client = MockClient((_) async => http.Response('Not Found', 404));
      final parser = ReadabilityArticleParser(httpClient: client);

      await expectLater(
        parser.parse('https://example.com/missing'),
        throwsA(
          isA<ArticleParserException>()
              .having(
                (e) => e.reason,
                'reason',
                ArticleParserFailure.httpStatus,
              )
              .having((e) => e.statusCode, 'statusCode', 404),
        ),
      );
    });

    test('parse throws network on client exception', () async {
      final client = MockClient(
        (_) async => throw Exception('Connection refused'),
      );
      final parser = ReadabilityArticleParser(httpClient: client);

      await expectLater(
        parser.parse('https://example.com/story'),
        throwsA(
          isA<ArticleParserException>().having(
            (e) => e.reason,
            'reason',
            ArticleParserFailure.network,
          ),
        ),
      );
    });

    test('parse throws noContent when readability returns nothing', () async {
      // A page without any article-like content: readability should bail.
      final client = MockClient((_) async {
        return http.Response(
          '<html><body></body></html>',
          200,
          headers: const {'content-type': 'text/html; charset=utf-8'},
        );
      });
      final parser = ReadabilityArticleParser(httpClient: client);

      await expectLater(
        parser.parse('https://example.com/empty'),
        throwsA(
          isA<ArticleParserException>().having(
            (e) => e.reason,
            'reason',
            ArticleParserFailure.noContent,
          ),
        ),
      );
    });
  });
}
