import 'dart:convert';

import 'package:article_extraction_service/article_extraction_service.dart';
import 'package:domain_models/domain_models.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  test('posts URL to cleaner API before downloading client HTML', () async {
    late Map<String, Object?> requestBody;
    final service = TrafilaturaArticleExtractionService(
      baseUri: Uri.parse('http://127.0.0.1:9090'),
      apiKey: 'secret',
      httpClient: MockClient((request) async {
        if (request.method == 'GET') {
          fail('Server extraction should succeed before client HTML download.');
        }

        expect(request.method, 'POST');
        expect(request.url.path, '/v1/extract');
        expect(request.headers['X-API-Key'], 'secret');
        expect(request.headers['ngrok-skip-browser-warning'], 'true');
        requestBody = jsonDecode(request.body) as Map<String, Object?>;
        return _articleResponse(
          title: 'Readable article',
          site: 'Example',
          text: 'Hello world',
        );
      }),
    );

    final article = await service.extract('https://example.com/a');

    expect(requestBody['url'], 'https://example.com/a');
    expect(requestBody.containsKey('html_base64'), isFalse);
    expect(requestBody['body_format'], 'blocks');
    expect(requestBody['include_comments'], isFalse);
    expect(requestBody['include_tables'], isTrue);
    expect(requestBody['include_images'], isTrue);
    expect(requestBody['include_links'], isFalse);
    expect(requestBody['favor_precision'], isTrue);
    expect(requestBody['favor_recall'], isFalse);
    expect(article.title, 'Readable article');
    expect(article.site, 'Example');
    expect(
      article.blocks.single,
      const ArticleParagraphBlock(text: 'Hello world'),
    );
  });

  test('falls back to client HTML when server cannot fetch article', () async {
    final events = <String>[];
    late Map<String, Object?> htmlRequestBody;
    final service = TrafilaturaArticleExtractionService(
      baseUri: Uri.parse('http://127.0.0.1:9090'),
      httpClient: MockClient((request) async {
        if (request.method == 'GET') {
          events.add('GET ${request.url}');
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

        events.add('POST ${request.url.path}');
        if (request.url.path == '/v1/extract') {
          return _errorResponse(
            'Backend download failed',
            502,
            code: 'fetch_failed',
          );
        }

        expect(request.url.path, '/v1/extract-html');
        htmlRequestBody = jsonDecode(request.body) as Map<String, Object?>;
        return _articleResponse(title: 'Readable article', text: 'Hello world');
      }),
    );

    final article = await service.extract('https://example.com/a');

    expect(events, [
      'POST /v1/extract',
      'GET https://example.com/a',
      'POST /v1/extract-html',
    ]);
    expect(htmlRequestBody['url'], 'https://example.com/a');
    expect(htmlRequestBody['resolved_url'], 'https://example.com/a');
    final htmlBytes = base64Decode(htmlRequestBody['html_base64']! as String);
    expect(utf8.decode(htmlBytes), contains('<article>Hello world</article>'));
    expect(htmlRequestBody['content_type'], 'text/html; charset=utf-8');
    expect(article.title, 'Readable article');
    expect(article.plainText, 'Hello world');
  });

  test(
    'recovers language and RTL direction from downloaded HTML metadata',
    () async {
      late Map<String, Object?> htmlRequestBody;
      final service = TrafilaturaArticleExtractionService(
        baseUri: Uri.parse('http://127.0.0.1:9090'),
        httpClient: MockClient((request) async {
          if (request.method == 'GET') {
            return http.Response(
              '<!doctype html><html lang="ar" dir="rtl"><head>'
              '<meta property="og:locale" content="ar_AR"/>'
              '</head><body><article>مرحبا بالعالم</article></body></html>',
              200,
              headers: {'content-type': 'text/html; charset=utf-8'},
              request: request,
            );
          }

          if (request.url.path == '/v1/extract') {
            return _errorResponse(
              'Backend download failed',
              502,
              code: 'fetch_failed',
            );
          }

          htmlRequestBody = jsonDecode(request.body) as Map<String, Object?>;
          return _articleResponse(title: 'خبر عربي', text: 'مرحبا بالعالم');
        }),
      );

      final article = await service.extract('https://example.com/a');
      final postedHtml = utf8.decode(
        base64Decode(htmlRequestBody['html_base64']! as String),
      );

      expect(postedHtml, contains('dir="rtl"'));
      expect(article.language, 'ar');
      expect(article.textDirection, ArticleTextDirection.rtl);
      expect(article.rawJson, contains('"language":"ar"'));
      expect(article.rawJson, contains('"text_direction":"rtl"'));
    },
  );

  test(
    'recovers image blocks from JSON-LD article body markers after fallback',
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

          if (request.url.path == '/v1/extract') {
            return _errorResponse(
              'Backend download failed',
              502,
              code: 'fetch_failed',
            );
          }

          return _jsonResponse({
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
          });
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

  test('maps article download failures from client fallback', () async {
    final service = TrafilaturaArticleExtractionService(
      baseUri: Uri.parse('http://127.0.0.1:9090'),
      httpClient: MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response('Not found', 404, request: request);
        }
        return _errorResponse(
          'Backend download failed',
          502,
          code: 'fetch_failed',
        );
      }),
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
  });

  test('stops downloading when fallback HTML exceeds the size limit', () async {
    final service = TrafilaturaArticleExtractionService(
      baseUri: Uri.parse('http://127.0.0.1:9090'),
      maxDownloadBytes: 4,
      httpClient: MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response('too large', 200, request: request);
        }
        return _errorResponse(
          'Backend download failed',
          502,
          code: 'fetch_failed',
        );
      }),
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

  test('maps backend error payloads without client fallback', () async {
    final paths = <String>[];
    final service = TrafilaturaArticleExtractionService(
      baseUri: Uri.parse('http://127.0.0.1:9090'),
      httpClient: MockClient((request) async {
        if (request.method == 'GET') {
          fail('Backend validation errors must not trigger client fallback.');
        }
        paths.add(request.url.path);
        return _errorResponse('Bad URL', 422, code: 'invalid_url');
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
    expect(paths, ['/v1/extract']);
  });

  test('maps cleaner connection failures without client fallback', () async {
    final service = TrafilaturaArticleExtractionService(
      baseUri: Uri.parse('http://127.0.0.1:9090'),
      httpClient: MockClient((request) async {
        if (request.method == 'GET') {
          fail('Cleaner connection failures must not trigger client fallback.');
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
  });

  test(
    'retries server extraction with recall when precision extracts nothing',
    () async {
      final requestBodies = <Map<String, Object?>>[];
      final service = TrafilaturaArticleExtractionService(
        baseUri: Uri.parse('http://127.0.0.1:9090'),
        httpClient: MockClient((request) async {
          if (request.method == 'GET') {
            fail('Server recall retry should succeed before client fallback.');
          }

          expect(request.url.path, '/v1/extract');
          requestBodies.add(jsonDecode(request.body) as Map<String, Object?>);
          if (requestBodies.length == 1) {
            return _errorResponse(
              'No readable article body',
              422,
              code: 'extract_failed',
            );
          }
          return _articleResponse(text: 'Server recall worked');
        }),
      );

      final article = await service.extract('https://example.com/a');

      expect(requestBodies, hasLength(2));
      expect(requestBodies.first.containsKey('html_base64'), isFalse);
      expect(requestBodies.last.containsKey('html_base64'), isFalse);
      expect(requestBodies.first['favor_precision'], isTrue);
      expect(requestBodies.first['favor_recall'], isFalse);
      expect(requestBodies.last['favor_precision'], isFalse);
      expect(requestBodies.last['favor_recall'], isTrue);
      expect(article.plainText, 'Server recall worked');
    },
  );

  test(
    'falls back to client HTML when server precision and recall cannot extract',
    () async {
      final events = <String>[];
      final serverBodies = <Map<String, Object?>>[];
      late Map<String, Object?> htmlRequestBody;
      final service = TrafilaturaArticleExtractionService(
        baseUri: Uri.parse('http://127.0.0.1:9090'),
        httpClient: MockClient((request) async {
          if (request.method == 'GET') {
            events.add('GET ${request.url}');
            return http.Response(
              '<html>challenge</html>',
              200,
              request: request,
            );
          }

          events.add('POST ${request.url.path}');
          if (request.url.path == '/v1/extract') {
            serverBodies.add(jsonDecode(request.body) as Map<String, Object?>);
            return _errorResponse(
              'No readable article body',
              422,
              code: 'extract_failed',
            );
          }

          expect(request.url.path, '/v1/extract-html');
          htmlRequestBody = jsonDecode(request.body) as Map<String, Object?>;
          return _articleResponse(
            title: 'Client extracted article',
            text: 'Client fallback worked',
          );
        }),
      );

      final article = await service.extract('https://example.com/a');

      expect(events, [
        'POST /v1/extract',
        'POST /v1/extract',
        'GET https://example.com/a',
        'POST /v1/extract-html',
      ]);
      expect(serverBodies.first['favor_precision'], isTrue);
      expect(serverBodies.last['favor_recall'], isTrue);
      expect(htmlRequestBody.containsKey('html_base64'), isTrue);
      expect(article.title, 'Client extracted article');
      expect(article.plainText, 'Client fallback worked');
    },
  );

  test(
    'does not fall back to client HTML on cleaner authentication failure',
    () async {
      final paths = <String>[];
      final service = TrafilaturaArticleExtractionService(
        baseUri: Uri.parse('http://127.0.0.1:9090'),
        httpClient: MockClient((request) async {
          if (request.method == 'GET') {
            fail('Authentication failures must not trigger client fallback.');
          }
          paths.add(request.url.path);
          return http.Response('', 403);
        }),
      );

      await expectLater(
        service.extract('https://example.com/a'),
        throwsA(
          isA<ArticleExtractionException>()
              .having(
                (e) => e.message,
                'message',
                'Article cleaner authentication failed',
              )
              .having((e) => e.statusCode, 'statusCode', 403),
        ),
      );
      expect(paths, ['/v1/extract']);
    },
  );

  test('falls back to client HTML when server stops unsafe redirect', () async {
    final paths = <String>[];
    final service = TrafilaturaArticleExtractionService(
      baseUri: Uri.parse('http://127.0.0.1:9090'),
      httpClient: MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(
            '<html><body><article>Safe fallback</article></body></html>',
            200,
            request: request,
          );
        }

        paths.add(request.url.path);
        if (request.url.path == '/v1/extract') {
          return _errorResponse(
            'Unsafe redirect stopped',
            508,
            code: 'unsafe_redirect',
          );
        }
        return _articleResponse(text: 'Safe fallback');
      }),
    );

    final article = await service.extract('https://example.com/a');

    expect(paths, ['/v1/extract', '/v1/extract-html']);
    expect(article.plainText, 'Safe fallback');
  });

  test('formats FastAPI validation errors without client fallback', () async {
    final service = TrafilaturaArticleExtractionService(
      baseUri: Uri.parse('http://127.0.0.1:9090'),
      httpClient: MockClient((request) async {
        if (request.method == 'GET') {
          fail('Validation errors must not trigger client fallback.');
        }
        return _jsonResponse(
          {
            'detail': [
              {
                'loc': ['body', 'url'],
                'msg': 'Field required',
                'type': 'missing',
              },
            ],
          },
          statusCode: 422,
        );
      }),
    );

    await expectLater(
      service.extract('https://example.com/a'),
      throwsA(
        isA<ArticleExtractionException>().having(
          (e) => e.message,
          'message',
          'body.url: Field required',
        ),
      ),
    );
  });

  test('rejects invalid URLs before backend or client requests', () async {
    final service = TrafilaturaArticleExtractionService(
      baseUri: Uri.parse('http://127.0.0.1:9090'),
      httpClient: MockClient((request) async {
        fail('Invalid URLs must not reach HTTP clients.');
      }),
    );

    await expectLater(
      service.extract('not a url'),
      throwsA(
        isA<ArticleExtractionException>().having(
          (e) => e.message,
          'message',
          'Enter a valid article URL',
        ),
      ),
    );
  });
}

http.Response _articleResponse({
  String title = 'Readable article',
  String? site,
  required String text,
}) {
  final body = <String, Object?>{
    'requested_url': 'https://example.com/a',
    'resolved_url': 'https://example.com/a',
    'title': title,
    'body_format': 'blocks',
    'body': [
      {'type': 'paragraph', 'text': text},
    ],
    'plain_text': text,
  };
  if (site != null) body['site'] = site;
  return _jsonResponse(body);
}

http.Response _errorResponse(
  String message,
  int statusCode, {
  String? code,
}) {
  final detail = code == null ? message : {'code': code, 'message': message};
  return _jsonResponse({'detail': detail}, statusCode: statusCode);
}

http.Response _jsonResponse(
  Object? body, {
  int statusCode = 200,
}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: {'content-type': 'application/json'},
  );
}
