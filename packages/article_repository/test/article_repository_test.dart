import 'dart:convert';
import 'dart:io';

import 'package:article_repository/article_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:local_storage/local_storage.dart';
import 'package:path/path.dart' as p;

void main() {
  late AppDatabase db;
  late Directory tempDir;
  late ArticleRepository repository;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
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
    'addExtractedArticle resolves relative image URLs into article HTML',
    () async {
      repository.dispose();
      repository = ArticleRepository(
        database: db,
        articlesDirectory: Directory(p.join(tempDir.path, 'articles')),
        httpClient: MockClient((request) async {
          expect(
            request.url.toString(),
            'https://example.com/images/photo.png',
          );
          return http.Response.bytes(
            [1, 2, 3],
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
}

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
