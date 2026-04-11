import 'dart:io';

import 'package:article_repository/article_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:local_storage/local_storage.dart';

void main() {
  late AppDatabase db;
  late Directory tempRoot;
  late Directory articlesDir;
  late Directory coversDir;
  late ArticleRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    tempRoot = Directory.systemTemp.createTempSync('article_repo_test_');
    articlesDir = Directory('${tempRoot.path}/articles');
    coversDir = Directory('${tempRoot.path}/covers');
    repo = ArticleRepository(
      database: db,
      articlesDirectory: articlesDir,
      coversDirectory: coversDir,
      // Default stub: every download succeeds with a tiny PNG payload.
      httpClient: MockClient(
        (_) async => http.Response.bytes(
          [0x89, 0x50, 0x4E, 0x47],
          200,
          headers: const {'content-type': 'image/png'},
        ),
      ),
    );
  });

  tearDown(() async {
    await db.close();
    if (tempRoot.existsSync()) {
      tempRoot.deleteSync(recursive: true);
    }
  });

  group('ArticleRepository', () {
    test('addArticle writes content to disk and returns article', () async {
      final article = await repo.addArticle(
        title: 'My Article',
        url: 'https://example.com/article',
        content: '<p>Hello</p>',
        siteName: 'Example',
      );
      expect(article.title, 'My Article');
      expect(article.siteName, 'Example');
      expect(article.id, isNotEmpty);
      expect(article.contentPath, endsWith('${article.id}.html'));
      expect(File(article.contentPath).existsSync(), isTrue);
      expect(File(article.contentPath).readAsStringSync(), '<p>Hello</p>');
    });

    test('addArticle persists readability metadata round-trip', () async {
      final created = await repo.addArticle(
        title: 'Metadata Article',
        url: 'https://example.com/meta',
        content: '<p>body</p>',
        siteName: 'Example Daily',
        byline: 'Jane Writer',
        excerpt: 'A short description.',
        publishedTime: '2026-04-01T12:00:00Z',
        lang: 'en',
        textLength: 1234,
        estimatedWordCount: 200,
      );

      final fetched = await repo.getArticleById(created.id);
      expect(fetched, isNotNull);
      expect(fetched!.byline, 'Jane Writer');
      expect(fetched.excerpt, 'A short description.');
      expect(fetched.publishedTime, '2026-04-01T12:00:00Z');
      expect(fetched.lang, 'en');
      expect(fetched.textLength, 1234);
      expect(fetched.estimatedWordCount, 200);
    });

    test('addArticle downloads cover image to covers directory', () async {
      final article = await repo.addArticle(
        title: 'With Cover',
        url: 'https://example.com/c',
        content: '<p>body</p>',
        coverImageUrl: 'https://cdn.example.com/cover.jpg',
      );
      expect(article.coverImageUrl, 'https://cdn.example.com/cover.jpg');
      expect(article.coverImagePath, isNotNull);
      expect(article.coverImagePath, contains(article.id));
      expect(File(article.coverImagePath!).existsSync(), isTrue);
    });

    test('addArticle keeps article even when cover download fails', () async {
      final failingRepo = ArticleRepository(
        database: db,
        articlesDirectory: articlesDir,
        coversDirectory: coversDir,
        httpClient: MockClient((_) async => http.Response('nope', 500)),
      );
      final article = await failingRepo.addArticle(
        title: 'Cover Fails',
        url: 'https://example.com/cf',
        content: '<p>body</p>',
        coverImageUrl: 'https://cdn.example.com/broken.jpg',
      );
      expect(article.coverImagePath, isNull);
      expect(article.coverImageUrl, 'https://cdn.example.com/broken.jpg');
      expect(File(article.contentPath).existsSync(), isTrue);
    });

    test('readContent returns the written HTML body', () async {
      final article = await repo.addArticle(
        title: 'Reader',
        url: 'https://example.com/r',
        content: '<h1>Title</h1><p>body</p>',
      );
      final content = await repo.readContent(article);
      expect(content, '<h1>Title</h1><p>body</p>');
    });

    test('getArticles returns all added articles', () async {
      await repo.addArticle(
        title: 'Art 1',
        url: 'https://a.com/1',
        content: '<p>1</p>',
      );
      await repo.addArticle(
        title: 'Art 2',
        url: 'https://a.com/2',
        content: '<p>2</p>',
      );
      final articles = await repo.getArticles();
      expect(articles, hasLength(2));
    });

    test('getArticleById returns correct article', () async {
      final created = await repo.addArticle(
        title: 'Find Article',
        url: 'https://a.com/find',
        content: '<p>found</p>',
      );
      final found = await repo.getArticleById(created.id);
      expect(found, isNotNull);
      expect(found!.title, 'Find Article');
    });

    test('deleteArticle removes article row and its files', () async {
      final created = await repo.addArticle(
        title: 'Remove',
        url: 'https://a.com/del',
        content: '<p>bye</p>',
        coverImageUrl: 'https://cdn.example.com/cover.jpg',
      );
      expect(File(created.contentPath).existsSync(), isTrue);
      expect(File(created.coverImagePath!).existsSync(), isTrue);

      await repo.deleteArticle(created.id);

      final articles = await repo.getArticles();
      expect(articles, isEmpty);
      expect(File(created.contentPath).existsSync(), isFalse);
      expect(File(created.coverImagePath!).existsSync(), isFalse);
    });

    test('updateArticle persists scroll offset', () async {
      final created = await repo.addArticle(
        title: 'Scroll',
        url: 'https://a.com/scroll',
        content: '<p>content</p>',
      );
      final updated = created.copyWith(currentScrollOffset: 123.4);
      await repo.updateArticle(updated);
      final fetched = await repo.getArticleById(created.id);
      expect(fetched!.currentScrollOffset, 123.4);
    });
  });
}
