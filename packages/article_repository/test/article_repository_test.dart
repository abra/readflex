import 'dart:convert';
import 'dart:io';

import 'package:article_repository/article_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:drift/drift.dart'
    show QueryInterceptor, QueryExecutor, ApplyInterceptor, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:local_storage/local_storage.dart';
import 'package:path/path.dart' as p;
import 'package:remote_content_policy/remote_content_policy.dart';

class _SelectRecorder extends QueryInterceptor {
  final columns = <Set<String>>[];

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    final rows = await executor.runSelect(statement, args);
    if (rows.isNotEmpty) columns.add(rows.first.keys.toSet());
    return rows;
  }
}

void main() {
  late AppDatabase db;
  late Directory tempDir;
  late ArticleRepository repository;
  late _SelectRecorder selects;

  setUp(() async {
    selects = _SelectRecorder();
    db = AppDatabase.forTesting(NativeDatabase.memory().interceptWith(selects));
    tempDir = await Directory.systemTemp.createTemp('article_repo_test_');
    repository = ArticleRepository(
      database: db,
      articlesDirectory: Directory(p.join(tempDir.path, 'articles')),
    );
  });

  tearDown(() async {
    repository.dispose();
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'library reads only metadata and leaves full article content intact',
    () async {
      final article = await repository.addExtractedArticle(_extractedArticle());
      final largeText = 'Large body. ' * 100000;
      await db.articlesDao.updateArticle(
        ArticlesTableCompanion(
          id: Value(article.id),
          plainText: Value(largeText),
          author: const Value('Author'),
          siteName: const Value('Site'),
          language: const Value('ru'),
          readingProgress: const Value(0.75),
          lastOpenedAt: const Value('2026-09-25T10:00:00.000Z'),
          isFinished: const Value(true),
        ),
      );
      final full = (await repository.getArticleById(article.id))!;
      selects.columns.clear();
      final sources = await repository.getLibrarySources();
      expect(sources, [LibrarySource.fromArticle(full)]);
      expect(selects.columns, hasLength(1));
      expect(selects.columns.single, isNot(contains('plain_text')));
      expect(selects.columns.single, isNot(contains('current_cfi')));
      expect(
        (await repository.getArticleById(article.id))!.plainText,
        largeText,
      );
    },
  );

  test('addExtractedArticle stores JSON and reader HTML', () async {
    final article = await repository.addExtractedArticle(_extractedArticle());

    expect(article.id, isNotEmpty);
    expect(article.title, 'Saved article');
    expect(File(article.contentPath).existsSync(), isTrue);
    expect(File(article.contentHtmlPath).existsSync(), isTrue);
    expect(
      File(p.join(p.dirname(article.contentPath), 'article.epub')).existsSync(),
      isFalse,
    );

    final stored = await repository.getArticleById(article.id);
    expect(stored, isNotNull);
    expect(stored!.plainText, 'Hello world');
  });

  test('addExtractedArticle removes duplicate leading title heading', () async {
    final article = await repository.addExtractedArticle(_extractedArticle());

    final contentHtml = File(article.contentHtmlPath).readAsStringSync();
    expect(contentHtml, isNot(contains('<h1>Saved article</h1>')));
    expect(
      contentHtml,
      contains(
        '<p id="block-0" data-rf-block-id="block-0">'
        '<span id="block-0-s0" data-rf-sentence="0">Hello world</span></p>',
      ),
    );
  });

  test('addExtractedArticle marks text blocks with sentence anchors', () async {
    final article = await repository.addExtractedArticle(
      _extractedArticle(
        plainText: 'First sentence. Second sentence.',
        blocks: const [
          ArticleParagraphBlock(text: 'First sentence. Second sentence.'),
          ArticleQuoteBlock(text: 'Quoted one. Quoted two?'),
          ArticleListBlock(items: ['Item one. Item two!']),
        ],
      ),
    );

    final contentHtml = File(article.contentHtmlPath).readAsStringSync();

    expect(
      contentHtml,
      contains('<p id="block-0" data-rf-block-id="block-0">'),
    );
    expect(
      contentHtml,
      contains(
        '<span id="block-0-s0" data-rf-sentence="0">First sentence. </span>',
      ),
    );
    expect(
      contentHtml,
      contains(
        '<span id="block-0-s1" data-rf-sentence="1">Second sentence.</span>',
      ),
    );
    expect(
      contentHtml,
      contains('<blockquote id="block-1" data-rf-block-id="block-1">'),
    );
    expect(
      contentHtml,
      contains('<li id="block-3" data-rf-block-id="block-3">'),
    );
  });

  test(
    'addExtractedArticle writes article HTML images next to content',
    () async {
      final imageBytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADElEQVR4nGNgYAAAAAMAAWgmWQ0AAAAASUVORK5CYII=',
      );
      repository.dispose();
      repository = ArticleRepository(
        database: db,
        articlesDirectory: Directory(p.join(tempDir.path, 'articles')),
        remoteUriPolicy: _publicRemoteUriPolicy,
        httpClient: MockClient((request) async {
          expect(request.url.toString(), 'https://example.com/image.png');
          return http.Response.bytes(
            imageBytes,
            200,
            headers: {'content-type': 'image/png'},
          );
        }),
      );

      final article = await repository.addExtractedArticle(
        _extractedArticle(
          blocks: const [
            ArticleImageBlock(src: 'https://example.com/image.png', alt: 'One'),
          ],
        ),
      );

      final articleDir = Directory(p.dirname(article.contentPath));
      final contentHtml = File(article.contentHtmlPath).readAsStringSync();
      final match = RegExp(r'images/([^"]+\.png)').firstMatch(contentHtml);

      expect(match, isNotNull);
      expect(
        File(p.join(articleDir.path, match!.group(0)!)).existsSync(),
        true,
      );
    },
  );

  test(
    'addExtractedArticle maps headings into article HTML anchors',
    () async {
      final article = await repository.addExtractedArticle(
        _extractedArticle(
          blocks: const [
            ArticleHeadingBlock(level: 1, text: 'Saved article'),
            ArticleParagraphBlock(text: 'Intro'),
            ArticleHeadingBlock(level: 2, text: 'First section'),
            ArticleParagraphBlock(text: 'Body'),
            ArticleHeadingBlock(level: 3, text: 'Second & final'),
          ],
        ),
      );

      final contentHtml = File(article.contentHtmlPath).readAsStringSync();
      expect(contentHtml, contains('<h2 id="section-1">First section</h2>'));
      expect(
        contentHtml,
        contains('<h3 id="section-2">Second &amp; final</h3>'),
      );
    },
  );

  test(
    'addExtractedArticle stores normalized language for article reader',
    () async {
      final article = await repository.addExtractedArticle(
        _extractedArticle(
          title: 'خبر عربي',
          language: 'ar-EG',
          textDirection: ArticleTextDirection.rtl,
          plainText: 'مرحبا بالعالم',
          blocks: const [ArticleParagraphBlock(text: 'مرحبا بالعالم')],
        ),
      );

      final contentHtml = File(article.contentHtmlPath).readAsStringSync();

      expect(article.language, 'ar-eg');
      expect(contentHtml, contains('مرحبا بالعالم'));
      expect(
        File(
          p.join(p.dirname(article.contentPath), 'article.epub'),
        ).existsSync(),
        isFalse,
      );
    },
  );

  test('addExtractedArticle exposes HTML reader path', () async {
    final article = await repository.addExtractedArticle(_extractedArticle());

    expect(article.contentHtmlPath, endsWith('content.html'));
    expect(File(article.contentHtmlPath).existsSync(), isTrue);
  });

  test('deleteArticle removes row and stored files', () async {
    final article = await repository.addExtractedArticle(_extractedArticle());
    final articleDir = Directory(p.dirname(article.contentPath));

    await repository.deleteArticle(article.id);

    expect(await repository.getArticleById(article.id), isNull);
    expect(await articleDir.exists(), isFalse);
  });

  test(
    'reader position and opened timestamp preserve article metadata',
    () async {
      final article = await repository.addExtractedArticle(_extractedArticle());
      final openedAt = DateTime(2026, 9, 5);
      await repository.updateArticle(
        article.copyWith(title: 'Edited', isFinished: true),
      );
      await repository.markOpened(article.id, openedAt);
      await repository.updateReadingPosition(
        article.id,
        cfi: 'latest',
        progress: 0.7,
      );
      final stored = (await repository.getArticleById(article.id))!;
      expect(stored.title, 'Edited');
      expect(stored.isFinished, isTrue);
      expect(stored.lastOpenedAt, openedAt);
      expect(stored.currentCfi, 'latest');
      expect(stored.readingProgress, 0.7);
    },
  );

  test(
    'addExtractedArticle resolves relative image URLs into article HTML',
    () async {
      repository.dispose();
      repository = ArticleRepository(
        database: db,
        articlesDirectory: Directory(p.join(tempDir.path, 'articles')),
        remoteUriPolicy: _publicRemoteUriPolicy,
        httpClient: MockClient((request) async {
          expect(
            request.url.toString(),
            'https://example.com/images/photo.png',
          );
          return http.Response.bytes(
            _pngBytes,
            200,
            headers: {'content-type': 'image/png'},
          );
        }),
      );

      final article = await repository.addExtractedArticle(
        _extractedArticle(
          requestedUrl: 'https://example.com/articles/story',
          blocks: const [
            ArticleParagraphBlock(text: 'Hello world'),
            ArticleImageBlock(src: '/images/photo.png', alt: 'Photo'),
          ],
        ),
      );

      final articleDir = Directory(p.dirname(article.contentPath));
      final contentHtml = File(article.contentHtmlPath).readAsStringSync();
      expect(contentHtml, contains('src="images/'));
      expect(contentHtml, isNot(contains('/images/photo.png')));

      final match = RegExp(r'images/([^"]+\.png)').firstMatch(contentHtml);
      expect(match, isNotNull);
      expect(
        File(p.join(articleDir.path, match!.group(0)!)).existsSync(),
        isTrue,
      );
    },
  );

  test('does not request article images from private addresses', () async {
    repository.dispose();
    repository = ArticleRepository(
      database: db,
      articlesDirectory: Directory(p.join(tempDir.path, 'articles')),
      httpClient: MockClient((request) async {
        fail('Private image URLs must not reach the HTTP client.');
      }),
    );

    final article = await repository.addExtractedArticle(
      _extractedArticle(
        blocks: const [
          ArticleImageBlock(src: 'http://127.0.0.1/private.png'),
        ],
      ),
    );

    final contentHtml = File(article.contentHtmlPath).readAsStringSync();
    final imagesDir = Directory(
      p.join(p.dirname(article.contentPath), 'images'),
    );
    expect(contentHtml, isNot(contains('src=')));
    expect(contentHtml, isNot(contains('src="images/')));
    expect(imagesDir.listSync().whereType<File>(), isEmpty);
  });

  test('does not persist images that exceed the per-file limit', () async {
    repository.dispose();
    repository = ArticleRepository(
      database: db,
      articlesDirectory: Directory(p.join(tempDir.path, 'articles')),
      remoteUriPolicy: _publicRemoteUriPolicy,
      maxImageBytes: 16,
      maxTotalImageBytes: 16,
      httpClient: MockClient((request) async {
        return http.Response.bytes(
          _pngBytes,
          200,
          headers: {'content-type': 'image/png'},
        );
      }),
    );

    final article = await repository.addExtractedArticle(
      _extractedArticle(
        blocks: const [
          ArticleImageBlock(src: 'https://example.com/large.png'),
        ],
      ),
    );

    final contentHtml = File(article.contentHtmlPath).readAsStringSync();
    final imagesDir = Directory(
      p.join(p.dirname(article.contentPath), 'images'),
    );
    expect(contentHtml, isNot(contains('src=')));
    expect(contentHtml, isNot(contains('src="images/')));
    expect(imagesDir.listSync().whereType<File>(), isEmpty);
  });

  test('limits the number of unique article image downloads', () async {
    var requests = 0;
    repository.dispose();
    repository = ArticleRepository(
      database: db,
      articlesDirectory: Directory(p.join(tempDir.path, 'articles')),
      remoteUriPolicy: _publicRemoteUriPolicy,
      maxArticleImages: 1,
      httpClient: MockClient((request) async {
        requests++;
        return http.Response.bytes(
          _pngBytes,
          200,
          headers: {'content-type': 'image/png'},
        );
      }),
    );

    final article = await repository.addExtractedArticle(
      _extractedArticle(
        blocks: const [
          ArticleImageBlock(src: 'https://example.com/first.png'),
          ArticleImageBlock(src: 'https://example.com/second.png'),
        ],
      ),
    );

    final contentHtml = File(article.contentHtmlPath).readAsStringSync();
    expect(requests, 1);
    expect(contentHtml, contains('src="images/'));
    expect(RegExp('src=').allMatches(contentHtml), hasLength(1));
  });

  test(
    'counts rejected image payloads against the total byte budget',
    () async {
      repository.dispose();
      repository = ArticleRepository(
        database: db,
        articlesDirectory: Directory(p.join(tempDir.path, 'articles')),
        remoteUriPolicy: _publicRemoteUriPolicy,
        maxImageBytes: 128,
        maxTotalImageBytes: 80,
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('invalid.bin')) {
            return http.Response.bytes(
              List<int>.filled(60, 0),
              200,
              headers: {'content-type': 'application/octet-stream'},
            );
          }
          return http.Response.bytes(
            _pngBytes,
            200,
            headers: {'content-type': 'image/png'},
          );
        }),
      );

      final article = await repository.addExtractedArticle(
        _extractedArticle(
          blocks: const [
            ArticleImageBlock(src: 'https://example.com/invalid.bin'),
            ArticleImageBlock(src: 'https://example.com/valid.png'),
          ],
        ),
      );

      final contentHtml = File(article.contentHtmlPath).readAsStringSync();
      final imagesDir = Directory(
        p.join(p.dirname(article.contentPath), 'images'),
      );
      expect(contentHtml, isNot(contains('src="images/')));
      expect(contentHtml, isNot(contains('src=')));
      expect(imagesDir.listSync().whereType<File>(), isEmpty);
    },
  );
  test(
    'rewrites exact image sources including query strings and duplicates',
    () async {
      final requested = <Uri>[];
      repository.dispose();
      repository = ArticleRepository(
        database: db,
        articlesDirectory: Directory(p.join(tempDir.path, 'articles')),
        remoteUriPolicy: _publicRemoteUriPolicy,
        httpClient: MockClient((request) async {
          requested.add(request.url);
          return http.Response.bytes(
            _pngBytes,
            200,
            headers: {'content-type': 'image/png'},
          );
        }),
      );
      final article = await repository.addExtractedArticle(
        _extractedArticle(
          blocks: const [
            ArticleImageBlock(src: 'https://example.com/image.png'),
            ArticleImageBlock(
              src: 'https://example.com/image.png?width=500&height=300',
            ),
            ArticleImageBlock(src: 'https://example.com/image.png'),
            ArticleImageBlock(
              src: 'https://example.com/image.png?literal=&amp;',
            ),
          ],
        ),
      );
      final html = await File(article.contentHtmlPath).readAsString();
      final sources = RegExp(
        'src="([^"]+)"',
      ).allMatches(html).map((match) => match.group(1)!).toList();
      expect(requested.map((uri) => uri.toString()), [
        'https://example.com/image.png',
        'https://example.com/image.png?width=500&height=300',
        'https://example.com/image.png?literal=&amp;',
      ]);
      expect(sources, hasLength(4));
      expect(sources[0], sources[2]);
      expect(sources[1], isNot(sources[0]));
      for (final source in sources) {
        expect(source, isNot(contains('?')));
        expect(
          await File(p.join(p.dirname(article.contentPath), source)).exists(),
          isTrue,
        );
      }
    },
  );

  test('redirects to private images remain inactive in saved HTML', () async {
    repository.dispose();
    var requests = 0;
    repository = ArticleRepository(
      database: db,
      articlesDirectory: Directory(p.join(tempDir.path, 'articles')),
      remoteUriPolicy: _publicRemoteUriPolicy,
      httpClient: MockClient((request) async {
        requests++;
        return http.Response(
          '',
          302,
          headers: {'location': 'http://127.0.0.1/private.png'},
        );
      }),
    );
    final article = await repository.addExtractedArticle(
      _extractedArticle(
        blocks: const [
          ArticleImageBlock(
            src: 'https://example.com/redirect.png',
            alt: 'Preserved alternative',
          ),
        ],
      ),
    );
    final html = await File(article.contentHtmlPath).readAsString();
    expect(requests, 1);
    expect(html, isNot(contains('src=')));
    expect(html, contains('Preserved alternative'));
  });
}

final _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADElEQVR4nGNgYAAAAAMAAWgmWQ0AAAAASUVORK5CYII=',
);

final _publicRemoteUriPolicy = RemoteUriPolicy(
  resolveHost: (_) async => [InternetAddress('93.184.216.34')],
);

ExtractedArticle _extractedArticle({
  String requestedUrl = 'https://example.com/article',
  String title = 'Saved article',
  String plainText = 'Hello world',
  String? language,
  ArticleTextDirection? textDirection,
  List<ArticleBlock> blocks = const [
    ArticleHeadingBlock(level: 1, text: 'Saved article'),
    ArticleParagraphBlock(text: 'Hello world'),
  ],
}) => ExtractedArticle(
  requestedUrl: requestedUrl,
  title: title,
  site: 'Example',
  language: language,
  textDirection: textDirection,
  blocks: blocks,
  plainText: plainText,
  rawJson: jsonEncode({'title': title}),
);
