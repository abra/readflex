import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
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

  test('addExtractedArticle stores content and builds reader epub', () async {
    final article = await repository.addExtractedArticle(_extractedArticle());

    expect(article.id, isNotEmpty);
    expect(article.title, 'Saved article');
    expect(File(article.contentPath).existsSync(), isTrue);
    expect(File(article.epubPath).existsSync(), isTrue);

    final stored = await repository.getArticleById(article.id);
    expect(stored, isNotNull);
    expect(stored!.plainText, 'Hello world');
  });

  test('addExtractedArticle removes duplicate leading title heading', () async {
    final article = await repository.addExtractedArticle(_extractedArticle());

    final contentHtml = File(
      p.join(p.dirname(article.contentPath), 'content.html'),
    ).readAsStringSync();
    expect(contentHtml, isNot(contains('<h1>Saved article</h1>')));

    final archive = ZipDecoder().decodeBytes(
      File(article.epubPath).readAsBytesSync(),
    );
    final chapter = _archiveText(archive, 'OEBPS/chapter1.xhtml');
    expect(RegExp('<h1>Saved article</h1>').allMatches(chapter), hasLength(1));
    expect(chapter, contains('<p>Hello world</p>'));
  });

  test('toReaderBook adapts article to existing reader contract', () async {
    final article = await repository.addExtractedArticle(_extractedArticle());

    final readerBook = repository.toReaderBook(article);

    expect(readerBook.id, article.id);
    expect(readerBook.format, BookFormat.epub);
    expect(readerBook.filePath, article.epubPath);
    expect(readerBook.author, 'Example');
  });

  test('deleteArticle removes row and stored files', () async {
    final article = await repository.addExtractedArticle(_extractedArticle());
    final articleDir = Directory(p.dirname(article.contentPath));

    await repository.deleteArticle(article.id);

    expect(await repository.getArticleById(article.id), isNull);
    expect(await articleDir.exists(), isFalse);
  });

  test('addExtractedArticle resolves relative image URLs into epub', () async {
    repository.dispose();
    repository = ArticleRepository(
      database: db,
      articlesDirectory: Directory(p.join(tempDir.path, 'articles')),
      httpClient: MockClient((request) async {
        expect(request.url.toString(), 'https://example.com/images/photo.png');
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

    final contentHtml = File(
      p.join(p.dirname(article.contentPath), 'content.html'),
    ).readAsStringSync();
    expect(contentHtml, contains('src="images/'));
    expect(contentHtml, isNot(contains('/images/photo.png')));

    final archive = ZipDecoder().decodeBytes(
      File(article.epubPath).readAsBytesSync(),
    );
    expect(
      archive.files.any(
        (file) =>
            file.name.startsWith('OEBPS/images/') && file.name.endsWith('.png'),
      ),
      isTrue,
    );
  });
}

String _archiveText(Archive archive, String name) {
  final file = archive.files.firstWhere((file) => file.name == name);
  return utf8.decode(file.content as List<int>);
}

ExtractedArticle _extractedArticle({
  String requestedUrl = 'https://example.com/article',
  List<ArticleBlock> blocks = const [
    ArticleHeadingBlock(level: 1, text: 'Saved article'),
    ArticleParagraphBlock(text: 'Hello world'),
  ],
}) => ExtractedArticle(
  requestedUrl: requestedUrl,
  title: 'Saved article',
  site: 'Example',
  blocks: blocks,
  plainText: 'Hello world',
  rawJson: '{"title":"Saved article"}',
);
