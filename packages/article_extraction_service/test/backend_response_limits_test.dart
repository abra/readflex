import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:article_extraction_service/article_extraction_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:remote_content_policy/remote_content_policy.dart';
import 'package:test/test.dart';

void main() {
  test('maps a large cleaner JSON response into domain data', () async {
    final text = 'Long article sentence. ' * 20000;
    final service = TrafilaturaArticleExtractionService(
      baseUri: Uri.parse('https://api.readflex.app'),
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'requested_url': 'https://example.com/article',
            'title': 'Large article',
            'body': [
              {'type': 'paragraph', 'text': text},
            ],
            'plain_text': text,
            'language': 'EN-us',
          }),
          200,
        ),
      ),
    );
    addTearDown(service.dispose);
    final article = await service.extract('https://example.com/article');
    expect(article.title, 'Large article');
    expect(article.plainText, text);
    expect(article.blocks.single.fallbackText, text);
    expect(article.language, 'en-us');
    expect(jsonDecode(article.rawJson)['plain_text'], text);
  });

  for (final padding in [0, 300000]) {
    test(
      'malformed cleaner JSON stays a typed failure ($padding padding)',
      () async {
        final service = TrafilaturaArticleExtractionService(
          baseUri: Uri.parse('https://api.readflex.app'),
          httpClient: MockClient(
            (_) async => http.Response('{${' ' * padding}', 200),
          ),
        );
        addTearDown(service.dispose);
        await expectLater(
          service.extract('https://example.com/article'),
          throwsA(
            isA<ArticleExtractionException>().having(
              (error) => error.message,
              'message',
              'Invalid article response',
            ),
          ),
        );
      },
    );
  }

  test(
    'large error parsing retains the backend status and stable error code',
    () async {
      final service = TrafilaturaArticleExtractionService(
        baseUri: Uri.parse('https://api.readflex.app'),
        httpClient: MockClient(
          (_) async => http.Response(
            '${' ' * 300000}{"detail":{"code":"denied","message":"Denied"}}',
            401,
          ),
        ),
      );
      addTearDown(service.dispose);
      await expectLater(
        service.extract('https://example.com/article'),
        throwsA(
          isA<ArticleExtractionException>()
              .having((error) => error.statusCode, 'statusCode', 401)
              .having((error) => error.errorCode, 'errorCode', 'denied')
              .having((error) => error.message, 'message', 'Denied'),
        ),
      );
    },
  );

  for (final htmlStep in [false, true]) {
    for (final status in [200, 503]) {
      test(
        'caps cleaner ${htmlStep ? 'HTML' : 'URL'} response $status',
        () async {
          final client = _BackendClient(
            htmlStep: htmlStep,
            oversizedStatus: status,
          );
          final service = _service(client);
          addTearDown(service.dispose);
          await expectLater(
            service.extract('https://example.com/article'),
            throwsA(
              isA<ArticleExtractionException>().having(
                (error) => error.message,
                'message',
                'Article cleaner response is too large',
              ),
            ),
          );
          await pumpEventQueue();
          expect(client.aborted, isTrue);
          expect(client.bodyCancelled, isTrue);
          expect(client.closed, isFalse);
          expect(
            client.posts,
            htmlStep ? ['/v1/extract', '/v1/extract-html'] : ['/v1/extract'],
          );
        },
      );
    }

    for (final sendHeaders in [false, true]) {
      test(
        'deadline aborts cleaner ${htmlStep ? 'HTML' : 'URL'} ${sendHeaders ? 'body' : 'connection'}',
        () async {
          final client = _BackendClient(
            htmlStep: htmlStep,
            sendHeaders: sendHeaders,
          );
          final service = _service(client);
          addTearDown(service.dispose);
          await expectLater(
            service.extract('https://example.com/article'),
            throwsA(
              isA<ArticleExtractionException>().having(
                (error) => error.message,
                'message',
                'Article cleaner request timed out',
              ),
            ),
          );
          await pumpEventQueue();
          expect(client.aborted, isTrue);
          if (sendHeaders) expect(client.bodyCancelled, isTrue);
          expect(client.closed, isFalse);
        },
      );
    }
  }
}

TrafilaturaArticleExtractionService _service(http.Client client) =>
    TrafilaturaArticleExtractionService(
      baseUri: Uri.parse('https://api.readflex.app'),
      httpClient: client,
      remoteContentHttpClient: client,
      remoteUriPolicy: RemoteUriPolicy(
        resolveHost: (_) async => [InternetAddress('93.184.216.34')],
      ),
      timeout: const Duration(milliseconds: 50),
      maxResponseBytes: 512,
    );

class _BackendClient extends http.BaseClient {
  _BackendClient({
    required this.htmlStep,
    this.oversizedStatus,
    this.sendHeaders = true,
  });

  final bool htmlStep;
  final int? oversizedStatus;
  final bool sendHeaders;
  final posts = <String>[];
  bool aborted = false;
  bool bodyCancelled = false;
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.method == 'GET') {
      return http.StreamedResponse(
        Stream.value(utf8.encode('<html><article>Text.</article></html>')),
        200,
        headers: {'content-type': 'text/html'},
      );
    }
    posts.add(request.url.path);
    if (htmlStep && request.url.path == '/v1/extract') {
      return http.StreamedResponse(
        Stream.value(
          utf8.encode(
            jsonEncode({
              'detail': {'code': 'fetch_failed', 'message': 'Fetch failed'},
            }),
          ),
        ),
        502,
      );
    }
    final abort = (request as http.AbortableRequest).abortTrigger!;
    unawaited(abort.then((_) => aborted = true));
    if (!sendHeaders) {
      await abort;
      throw http.RequestAbortedException(request.url);
    }
    if (oversizedStatus != null) {
      Stream<List<int>> chunks() async* {
        try {
          yield List.filled(300, 32);
          yield List.filled(300, 32);
          fail('The remaining oversized response must not be read');
        } finally {
          bodyCancelled = true;
        }
      }

      return http.StreamedResponse(
        chunks(),
        oversizedStatus!,
        contentLength: 1,
      );
    }
    final body = StreamController<List<int>>(
      onCancel: () => bodyCancelled = true,
    );
    unawaited(abort.then((_) => body.close()));
    return http.StreamedResponse(body.stream, 200);
  }

  @override
  void close() => closed = true;
}
