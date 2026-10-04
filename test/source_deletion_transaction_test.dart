import 'dart:io';

import 'package:article_repository/article_repository.dart';
import 'package:book_repository/book_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_storage/local_storage.dart';

void main() {
  for (final article in [false, true]) {
    for (final failCleanup in [false, true]) {
      test(
        'source and memberships delete atomically: article=$article failure=$failCleanup',
        () async {
          final db = AppDatabase.forTesting(NativeDatabase.memory());
          final directory = await Directory.systemTemp.createTemp(
            'source_delete_',
          );
          final books = BookRepository(
            database: db,
            booksDirectory: Directory('${directory.path}/books'),
          );
          final articles = ArticleRepository(
            database: db,
            articlesDirectory: Directory('${directory.path}/articles'),
          );
          addTearDown(() async {
            articles.dispose();
            await db.close();
            await directory.delete(recursive: true);
          });
          final String id;
          final String path;
          if (article) {
            final saved = await articles.addExtractedArticle(
              const ExtractedArticle(
                requestedUrl: 'https://example.com',
                title: 'Article',
                plainText: 'Text',
                blocks: [ArticleParagraphBlock(text: 'Text')],
                rawJson: '{}',
              ),
            );
            id = saved.id;
            path = saved.contentPath;
          } else {
            final file = await File(
              '${directory.path}/source.epub',
            ).writeAsString('fixture');
            final saved = await books.addBook(
              sourceFile: file,
              title: 'Book',
              format: BookFormat.epub,
            );
            id = saved.id;
            path = saved.filePath;
          }
          await db.collectionsDao.insertCollection(
            CollectionsTableCompanion.insert(
              id: 'collection',
              name: 'Reading',
              createdAt: '2026-10-04',
              updatedAt: '2026-10-04',
            ),
          );
          await db.collectionsDao.addSources(
            collectionId: 'collection',
            sourceIds: [id, 'other'],
            addedAt: '2026-10-04',
          );
          if (failCleanup) {
            await db.customStatement('''
            CREATE TRIGGER fail_cleanup BEFORE DELETE ON collection_sources_table
            BEGIN SELECT RAISE(ABORT, 'simulated storage failure'); END
          ''');
          }
          Future<void> delete() =>
              article ? articles.deleteArticle(id) : books.deleteBook(id);
          if (failCleanup) {
            await expectLater(delete(), throwsA(isA<StorageException>()));
          } else {
            await delete();
          }
          final stored = article
              ? await articles.getArticleById(id)
              : await books.getBookById(id);
          expect(stored != null, failCleanup);
          expect(await File(path).exists(), failCleanup);
          expect(
            await db.collectionsDao.sourceIdsForCollection('collection'),
            unorderedEquals([if (failCleanup) id, 'other']),
          );
        },
      );
    }
  }
}
