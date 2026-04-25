import 'dart:io';

import 'package:article_repository/article_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:local_storage/local_storage.dart';

void main() {
  late AppDatabase db;
  late Directory tempRoot;
  late Directory articlesDir;
  late ArticleRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    tempRoot = Directory.systemTemp.createTempSync('article_repo_test_');
    articlesDir = Directory('${tempRoot.path}/articles');
    repo = ArticleRepository(
      database: db,
      articlesDirectory: articlesDir,
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
    test('addArticle writes content to per-article directory', () async {
      final article = await repo.addArticle(
        title: 'My Article',
        url: 'https://example.com/article',
        content: '<p>Hello</p>',
        siteName: 'Example',
      );
      expect(article.title, 'My Article');
      expect(article.siteName, 'Example');
      expect(article.id, isNotEmpty);
      expect(article.contentPath, endsWith('${article.id}/content.html'));
      expect(File(article.contentPath).existsSync(), isTrue);
      expect(File(article.contentPath).readAsStringSync(), '<p>Hello</p>');
    });

    test('addArticle also packages an EPUB next to the HTML', () async {
      final article = await repo.addArticle(
        title: 'My Article',
        url: 'https://example.com/article',
        content: '<p>Hello</p>',
        byline: 'Jane',
        lang: 'en',
      );

      final epubFile = File(
        '${articlesDir.path}/${article.id}/article.epub',
      );
      expect(epubFile.existsSync(), isTrue);
      // Sanity check — first 30 bytes of the file include "mimetype"
      // (per the EPUB spec, the mimetype entry is uncompressed and first).
      final head = epubFile.readAsBytesSync().sublist(0, 60);
      expect(String.fromCharCodes(head), contains('mimetype'));
      expect(
        String.fromCharCodes(head),
        contains('application/epub+zip'),
      );
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

    test('addArticle downloads cover image into article directory', () async {
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

    test('addArticle downloads body images and rewrites src', () async {
      final article = await repo.addArticle(
        title: 'With Images',
        url: 'https://example.com/img',
        content: '<p>Text</p><img src="https://cdn.example.com/photo.png">',
      );
      final html = File(article.contentPath).readAsStringSync();
      // Original URL should be replaced with a local relative path.
      expect(html, isNot(contains('https://cdn.example.com/photo.png')));
      expect(html, contains('images/'));

      // Image file should exist in the article's images directory.
      final imgDir = Directory(
        '${articlesDir.path}/${article.id}/images',
      );
      expect(imgDir.existsSync(), isTrue);
      expect(imgDir.listSync(), hasLength(1));
    });

    test('addArticle keeps original src when image download fails', () async {
      final failingRepo = ArticleRepository(
        database: db,
        articlesDirectory: articlesDir,
        httpClient: MockClient((_) async => http.Response('nope', 500)),
      );
      final article = await failingRepo.addArticle(
        title: 'Img Fail',
        url: 'https://example.com/if',
        content: '<img src="https://cdn.example.com/broken.png"><p>text</p>',
      );
      final html = File(article.contentPath).readAsStringSync();
      expect(html, contains('https://cdn.example.com/broken.png'));
    });

    test('addArticle skips non-http image src', () async {
      final article = await repo.addArticle(
        title: 'Data URI',
        url: 'https://example.com/d',
        content: '<img src="data:image/png;base64,abc"><p>text</p>',
      );
      final html = File(article.contentPath).readAsStringSync();
      expect(html, contains('data:image/png;base64,abc'));
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

    test('addArticle wraps every <table> in a horizontal-scroll div', () async {
      // Without the wrapper, a wide table gets clipped at the foliate-js
      // column edge and the user can't see overflowing cells.
      final article = await repo.addArticle(
        title: 'Tables',
        url: 'https://example.com/t',
        content:
            '<p>before</p>'
            '<table><tr><td>a</td><td>b</td></tr></table>'
            '<p>middle</p>'
            '<table class="data"><tr><td>c</td></tr></table>'
            '<p>after</p>',
      );
      final html = File(article.contentPath).readAsStringSync();
      expect(
        html,
        '<p>before</p>'
        '<div class="rf-table-scroll"><table><tr><td>a</td><td>b</td>'
        '</tr></table></div>'
        '<p>middle</p>'
        '<div class="rf-table-scroll"><table class="data"><tr><td>c</td>'
        '</tr></table></div>'
        '<p>after</p>',
      );
    });

    test('addArticle leaves table-free HTML untouched', () async {
      final article = await repo.addArticle(
        title: 'No tables',
        url: 'https://example.com/nt',
        content: '<p>just paragraphs</p>',
      );
      final html = File(article.contentPath).readAsStringSync();
      expect(html, '<p>just paragraphs</p>');
    });

    test('readContent throws StorageException when file is missing', () async {
      // A silent empty-string return hides import corruption from the caller
      // and from observability. Missing content must surface as an error.
      final article = await repo.addArticle(
        title: 'Gone',
        url: 'https://example.com/g',
        content: '<p>bye</p>',
      );
      await File(article.contentPath).delete();

      await expectLater(
        () => repo.readContent(article),
        throwsA(isA<StorageException>()),
      );
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

    test('deleteArticle removes entire article directory', () async {
      final created = await repo.addArticle(
        title: 'Remove',
        url: 'https://a.com/del',
        content: '<img src="https://cdn.example.com/pic.png"><p>bye</p>',
        coverImageUrl: 'https://cdn.example.com/cover.jpg',
      );
      final articleDir = Directory('${articlesDir.path}/${created.id}');
      expect(articleDir.existsSync(), isTrue);

      await repo.deleteArticle(created.id);

      final articles = await repo.getArticles();
      expect(articles, isEmpty);
      expect(articleDir.existsSync(), isFalse);
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
