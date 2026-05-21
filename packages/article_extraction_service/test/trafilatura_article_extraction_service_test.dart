import 'dart:convert';

import 'package:article_extraction_service/article_extraction_service.dart';
import 'package:domain_models/domain_models.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  test(
    'downloads article HTML on device and posts it to cleaner API',
    () async {
      late Map<String, Object?> requestBody;
      final service = TrafilaturaArticleExtractionService(
        baseUri: Uri.parse('http://127.0.0.1:9090'),
        apiKey: 'secret',
        httpClient: MockClient((request) async {
          if (request.method == 'GET') {
            expect(request.url.toString(), 'https://example.com/a');
            expect(request.headers['user-agent'], contains('Mozilla/5.0'));
            expect(request.headers['accept-language'], 'en-US,en;q=0.9');
            return http.Response(
              '<html><body><article>Hello world</article></body></html>',
              200,
              headers: {'content-type': 'text/html; charset=utf-8'},
              request: request,
            );
          }

          expect(request.method, 'POST');
          expect(request.url.path, '/v1/extract-html');
          expect(request.headers['X-API-Key'], 'secret');
          requestBody = jsonDecode(request.body) as Map<String, Object?>;
          return http.Response(
            jsonEncode({
              'requested_url': 'https://example.com/a',
              'resolved_url': 'https://example.com/a',
              'title': 'Readable article',
              'site': 'Example',
              'body_format': 'blocks',
              'body': [
                {'type': 'paragraph', 'text': 'Hello world'},
              ],
              'plain_text': 'Hello world',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final article = await service.extract('https://example.com/a');

      expect(requestBody['url'], 'https://example.com/a');
      expect(requestBody['resolved_url'], 'https://example.com/a');
      final htmlBytes = base64Decode(requestBody['html_base64']! as String);
      expect(
        utf8.decode(htmlBytes),
        contains('<article>Hello world</article>'),
      );
      expect(requestBody['content_type'], 'text/html; charset=utf-8');
      expect(requestBody['body_format'], 'blocks');
      expect(requestBody['include_comments'], isFalse);
      expect(requestBody['favor_precision'], isTrue);
      expect(article.title, 'Readable article');
      expect(article.site, 'Example');
      expect(
        article.blocks.single,
        const ArticleParagraphBlock(text: 'Hello world'),
      );
    },
  );

  test(
    'recovers image blocks from JSON-LD article body markers',
    () async {
      const firstImage =
          'https://platform.example.com/images/first.jpg?quality=90&strip=all';
      const secondImage =
          'https://platform.example.com/images/second.jpg?quality=90&strip=all';
      final jsonLd = jsonEncode({
        '@context': 'https://schema.org',
        '@type': 'NewsArticle',
        'articleBody':
            'Intro\n'
            '[Image: Maximum Pleasure Guaranteed. $firstImage]\n'
            'Middle\n'
            '[Image: Maximum Pleasure Guaranteed. $secondImage]\n'
            'End',
      });
      final service = TrafilaturaArticleExtractionService(
        baseUri: Uri.parse('http://127.0.0.1:9090'),
        httpClient: MockClient((request) async {
          if (request.method == 'GET') {
            return http.Response(
              '<html><head>'
              '<script type="application/ld+json">$jsonLd</script>'
              '</head><body></body></html>',
              200,
              request: request,
            );
          }

          return http.Response(
            jsonEncode({
              'requested_url': 'https://example.com/a',
              'resolved_url': 'https://example.com/a',
              'title': 'Readable article',
              'site': 'Example',
              'body_format': 'blocks',
              'body': [
                {'type': 'paragraph', 'text': 'Intro'},
                {
                  'type': 'paragraph',
                  'text': 'Maximum Pleasure Guaranteed. Image: Apple',
                },
                {'type': 'paragraph', 'text': 'Middle'},
                {
                  'type': 'paragraph',
                  'text': 'Maximum Pleasure Guaranteed. Image: Apple',
                },
                {'type': 'paragraph', 'text': 'End'},
              ],
              'plain_text':
                  'Intro\n\nMaximum Pleasure Guaranteed. Image: Apple\n\n'
                  'Middle\n\nMaximum Pleasure Guaranteed. Image: Apple\n\nEnd',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final article = await service.extract('https://example.com/a');

      expect(article.blocks, [
        const ArticleParagraphBlock(text: 'Intro'),
        const ArticleImageBlock(
          src: firstImage,
          alt: 'Maximum Pleasure Guaranteed.',
          title: 'Maximum Pleasure Guaranteed. Image: Apple',
        ),
        const ArticleParagraphBlock(text: 'Middle'),
        const ArticleImageBlock(
          src: secondImage,
          alt: 'Maximum Pleasure Guaranteed.',
          title: 'Maximum Pleasure Guaranteed. Image: Apple',
        ),
        const ArticleParagraphBlock(text: 'End'),
      ]);
      expect(article.rawJson, contains('"type":"image"'));
      expect(article.rawJson, contains(firstImage));
      expect(article.rawJson, contains(secondImage));
    },
  );

  test(
    'maps article download failures into ArticleExtractionException',
    () async {
      final service = TrafilaturaArticleExtractionService(
        baseUri: Uri.parse('http://127.0.0.1:9090'),
        httpClient: MockClient(
          (request) async => http.Response('Not found', 404, request: request),
        ),
      );

      await expectLater(
        service.extract('https://example.com/missing'),
        throwsA(
          isA<ArticleExtractionException>()
              .having(
                (e) => e.message,
                'message',
                'Article URL returned HTTP status 404',
              )
              .having((e) => e.statusCode, 'statusCode', 404),
        ),
      );
    },
  );

  test('stops downloading when article HTML exceeds the size limit', () async {
    final service = TrafilaturaArticleExtractionService(
      baseUri: Uri.parse('http://127.0.0.1:9090'),
      maxDownloadBytes: 4,
      httpClient: MockClient(
        (request) async => http.Response('too large', 200, request: request),
      ),
    );

    await expectLater(
      service.extract('https://example.com/large'),
      throwsA(
        isA<ArticleExtractionException>()
            .having(
              (e) => e.message,
              'message',
              'Article is too large to import',
            )
            .having((e) => e.statusCode, 'statusCode', 413),
      ),
    );
  });

  test('maps backend error payloads into ArticleExtractionException', () async {
    final service = TrafilaturaArticleExtractionService(
      baseUri: Uri.parse('http://127.0.0.1:9090'),
      httpClient: MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response('<html></html>', 200, request: request);
        }
        return http.Response(jsonEncode({'detail': 'Bad URL'}), 422);
      }),
    );

    await expectLater(
      service.extract('https://example.com/a'),
      throwsA(
        isA<ArticleExtractionException>()
            .having((e) => e.message, 'message', 'Bad URL')
            .having((e) => e.statusCode, 'statusCode', 422),
      ),
    );
  });

  test(
    'maps cleaner connection failures into ArticleExtractionException',
    () async {
      final service = TrafilaturaArticleExtractionService(
        baseUri: Uri.parse('http://127.0.0.1:9090'),
        httpClient: MockClient((request) async {
          if (request.method == 'GET') {
            return http.Response('<html></html>', 200, request: request);
          }
          throw http.ClientException('connection refused', request.url);
        }),
      );

      await expectLater(
        service.extract('https://example.com/a'),
        throwsA(
          isA<ArticleExtractionException>().having(
            (e) => e.message,
            'message',
            'Article cleaner service is unavailable',
          ),
        ),
      );
    },
  );

  test(
    'retries extraction with recall when precision mode extracts nothing',
    () async {
      final requestBodies = <Map<String, Object?>>[];
      final service = TrafilaturaArticleExtractionService(
        baseUri: Uri.parse('http://127.0.0.1:9090'),
        httpClient: MockClient((request) async {
          if (request.method == 'GET') {
            return http.Response(
              '<html><body><p>Fallback worked</p></body></html>',
              200,
              request: request,
            );
          }

          requestBodies.add(jsonDecode(request.body) as Map<String, Object?>);
          if (requestBodies.length == 1) {
            return http.Response(
              jsonEncode({'detail': 'Could not extract article content'}),
              422,
            );
          }
          return http.Response(
            jsonEncode({
              'requested_url': 'https://example.com/a',
              'resolved_url': 'https://example.com/a',
              'body_format': 'blocks',
              'body': [
                {'type': 'paragraph', 'text': 'Fallback worked'},
              ],
              'plain_text': 'Fallback worked',
            }),
            200,
          );
        }),
      );

      final article = await service.extract('https://example.com/a');

      expect(requestBodies, hasLength(2));
      expect(
        requestBodies.first['html_base64'],
        requestBodies.last['html_base64'],
      );
      expect(requestBodies.first['favor_precision'], isTrue);
      expect(requestBodies.first['favor_recall'], isFalse);
      expect(requestBodies.last['favor_precision'], isFalse);
      expect(requestBodies.last['favor_recall'], isTrue);
      expect(article.plainText, 'Fallback worked');
    },
  );

  test(
    'falls back to server-side extraction when client HTML cannot be extracted',
    () async {
      final paths = <String>[];
      final service = TrafilaturaArticleExtractionService(
        baseUri: Uri.parse('http://127.0.0.1:9090'),
        httpClient: MockClient((request) async {
          if (request.method == 'GET') {
            return http.Response(
              '<html>challenge</html>',
              200,
              request: request,
            );
          }

          paths.add(request.url.path);
          if (request.url.path == '/v1/extract-html') {
            return http.Response(
              jsonEncode({'detail': 'Could not extract article content'}),
              422,
            );
          }

          expect(request.url.path, '/v1/extract');
          final requestBody = jsonDecode(request.body) as Map<String, Object?>;
          expect(requestBody, isNot(contains('html_base64')));
          return http.Response(
            jsonEncode({
              'requested_url': 'https://example.com/a',
              'resolved_url': 'https://example.com/a',
              'title': 'Server extracted article',
              'body_format': 'blocks',
              'body': [
                {'type': 'paragraph', 'text': 'Server fallback worked'},
              ],
              'plain_text': 'Server fallback worked',
            }),
            200,
          );
        }),
      );

      final article = await service.extract('https://example.com/a');

      expect(paths, ['/v1/extract-html', '/v1/extract-html', '/v1/extract']);
      expect(article.title, 'Server extracted article');
      expect(article.plainText, 'Server fallback worked');
    },
  );

  test(
    'falls back to server-side extraction when client download is forbidden',
    () async {
      final paths = <String>[];
      final service = TrafilaturaArticleExtractionService(
        baseUri: Uri.parse('http://127.0.0.1:9090'),
        httpClient: MockClient((request) async {
          if (request.method == 'GET') {
            return http.Response('Forbidden', 403, request: request);
          }

          paths.add(request.url.path);
          return http.Response(
            jsonEncode({
              'requested_url': 'https://example.com/a',
              'resolved_url': 'https://example.com/a',
              'title': 'Server extracted article',
              'body_format': 'blocks',
              'body': [
                {'type': 'paragraph', 'text': 'Server fallback worked'},
              ],
              'plain_text': 'Server fallback worked',
            }),
            200,
          );
        }),
      );

      final article = await service.extract('https://example.com/a');

      expect(paths, ['/v1/extract']);
      expect(article.title, 'Server extracted article');
    },
  );

  test('formats FastAPI validation errors', () async {
    final service = TrafilaturaArticleExtractionService(
      baseUri: Uri.parse('http://127.0.0.1:9090'),
      httpClient: MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response('<html></html>', 200, request: request);
        }
        return http.Response(
          jsonEncode({
            'detail': [
              {
                'loc': ['body', 'html_base64'],
                'msg': 'Field required',
                'type': 'missing',
              },
            ],
          }),
          422,
        );
      }),
    );

    await expectLater(
      service.extract('https://example.com/a'),
      throwsA(
        isA<ArticleExtractionException>().having(
          (e) => e.message,
          'message',
          'body.html_base64: Field required',
        ),
      ),
    );
  });
}
