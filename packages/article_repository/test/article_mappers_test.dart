import 'dart:io';

import 'package:domain_models/domain_models.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:local_storage/local_storage.dart';
import 'package:path/path.dart' as p;

import 'package:article_repository/src/mappers/article_to_domain.dart';
import 'package:article_repository/src/mappers/article_to_storage.dart';

void main() {
  final now = DateTime(2026, 4, 1);
  late Directory articlesDir;

  setUp(() {
    articlesDir = Directory.systemTemp.createTempSync('articles_test_');
  });

  tearDown(() {
    if (articlesDir.existsSync()) articlesDir.deleteSync(recursive: true);
  });

  group('ArticleToDomain', () {
    test('resolves paths against articles directory', () {
      final row = ArticlesTableData(
        id: 'a1',
        title: 'Test Article',
        siteName: 'Example',
        url: 'https://example.com',
        contentPath: 'content.html',
        coverImageUrl: 'https://example.com/cover.jpg',
        coverImagePath: 'cover.jpg',
        byline: 'Author',
        excerpt: 'Summary',
        publishedTime: '2026-01-01',
        lang: 'en',
        textLength: 5000,
        estimatedWordCount: 800,
        currentScrollOffset: 0.5,
        addedAt: now.toIso8601String(),
        lastOpenedAt: now.toIso8601String(),
        isFinished: false,
      );

      final article = row.toDomainModel(articlesDir: articlesDir);
      final expectedDir = p.join(articlesDir.path, 'a1');

      expect(article.id, 'a1');
      expect(article.title, 'Test Article');
      expect(article.siteName, 'Example');
      expect(article.contentPath, p.join(expectedDir, 'content.html'));
      expect(article.coverImagePath, p.join(expectedDir, 'cover.jpg'));
      expect(article.byline, 'Author');
      expect(article.excerpt, 'Summary');
      expect(article.publishedTime, '2026-01-01');
      expect(article.lang, 'en');
      expect(article.textLength, 5000);
      expect(article.estimatedWordCount, 800);
      expect(article.currentScrollOffset, 0.5);
      expect(article.addedAt, now);
      expect(article.lastOpenedAt, now);
      expect(article.isFinished, false);
    });

    test('handles null optional fields', () {
      final row = ArticlesTableData(
        id: 'a2',
        title: 'Minimal',
        siteName: null,
        url: 'https://example.com',
        contentPath: 'content.html',
        coverImageUrl: null,
        coverImagePath: null,
        byline: null,
        excerpt: null,
        publishedTime: null,
        lang: null,
        textLength: 0,
        estimatedWordCount: 0,
        currentScrollOffset: 0.0,
        addedAt: now.toIso8601String(),
        lastOpenedAt: null,
        isFinished: false,
      );

      final article = row.toDomainModel(articlesDir: articlesDir);

      expect(article.siteName, isNull);
      expect(article.coverImagePath, isNull);
      expect(article.coverImageUrl, isNull);
      expect(article.lastOpenedAt, isNull);
    });

    test('falls back to epoch for invalid date', () {
      final row = ArticlesTableData(
        id: 'a3',
        title: 'T',
        siteName: null,
        url: 'https://example.com',
        contentPath: 'c.html',
        coverImageUrl: null,
        coverImagePath: null,
        byline: null,
        excerpt: null,
        publishedTime: null,
        lang: null,
        textLength: 0,
        estimatedWordCount: 0,
        currentScrollOffset: 0.0,
        addedAt: 'bad-date',
        lastOpenedAt: null,
        isFinished: false,
      );

      expect(
        row.toDomainModel(articlesDir: articlesDir).addedAt,
        DateTime.fromMillisecondsSinceEpoch(0),
      );
    });
  });

  group('ArticleToStorage', () {
    test('strips path to filename only', () {
      final article = Article(
        id: 'a1',
        title: 'Test',
        url: 'https://example.com',
        contentPath: '/some/deep/path/content.html',
        coverImagePath: '/some/deep/path/cover.jpg',
        addedAt: now,
      );

      final companion = article.toStorageModel();

      expect(companion.contentPath, const Value('content.html'));
      expect(companion.coverImagePath, const Value('cover.jpg'));
    });

    test('handles null coverImagePath', () {
      final article = Article(
        id: 'a2',
        title: 'Test',
        url: 'https://example.com',
        contentPath: '/path/content.html',
        addedAt: now,
      );

      final companion = article.toStorageModel();

      expect(companion.coverImagePath, const Value(null));
    });

    test('round-trips filename through storage and back', () {
      final original = Article(
        id: 'a1',
        title: 'Test',
        url: 'https://example.com',
        contentPath: p.join(articlesDir.path, 'a1', 'content.html'),
        coverImagePath: p.join(articlesDir.path, 'a1', 'cover.jpg'),
        addedAt: now,
      );

      final companion = original.toStorageModel();
      final row = ArticlesTableData(
        id: companion.id.value,
        title: companion.title.value,
        siteName: companion.siteName.value,
        url: companion.url.value,
        contentPath: companion.contentPath.value,
        coverImageUrl: companion.coverImageUrl.value,
        coverImagePath: companion.coverImagePath.value,
        byline: companion.byline.value,
        excerpt: companion.excerpt.value,
        publishedTime: companion.publishedTime.value,
        lang: companion.lang.value,
        textLength: companion.textLength.value,
        estimatedWordCount: companion.estimatedWordCount.value,
        currentScrollOffset: companion.currentScrollOffset.value,
        addedAt: companion.addedAt.value,
        lastOpenedAt: companion.lastOpenedAt.value,
        isFinished: companion.isFinished.value,
      );
      final restored = row.toDomainModel(articlesDir: articlesDir);

      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.contentPath, original.contentPath);
      expect(restored.coverImagePath, original.coverImagePath);
    });
  });
}
