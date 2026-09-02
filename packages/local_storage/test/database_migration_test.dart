import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_storage/local_storage.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  late Directory documentsDirectory;
  late File databaseFile;
  AppDatabase? database;

  setUp(() async {
    documentsDirectory = await Directory.systemTemp.createTemp(
      'readflex_database_migration_',
    );
    databaseFile = File(p.join(documentsDirectory.path, 'readflex.db'));
  });

  tearDown(() async {
    await database?.close();
    if (await documentsDirectory.exists()) {
      await documentsDirectory.delete(recursive: true);
    }
  });

  Future<AppDatabase> openMigratedDatabase({
    Future<Directory> Function()? documentsDirectoryProvider,
  }) async {
    final result = AppDatabase.forTesting(
      NativeDatabase(databaseFile),
      documentsDirectoryProvider:
          documentsDirectoryProvider ?? () async => documentsDirectory,
    );
    database = result;
    await result.customSelect('SELECT 1').getSingle();
    return result;
  }

  test(
    'migrates v5 inline article HTML without deleting the article',
    () async {
      final legacy = _createLegacyDatabase(databaseFile, version: 5);
      legacy.execute(
        '''
        INSERT INTO articles_table (
          id, title, site_name, url, cleaned_html, cover_image_url, byline,
          excerpt, published_time, lang, text_length, estimated_word_count,
          current_scroll_offset, added_at, last_opened_at, is_finished
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
        [
          'article-v5',
          'Legacy article',
          'Example',
          'https://example.com/story',
          '<p>Preserved body</p>',
          'https://example.com/cover.jpg',
          'Legacy Author',
          'Legacy description',
          '2026-01-01T00:00:00.000Z',
          'en',
          14,
          2,
          0.35,
          '2026-01-02T00:00:00.000Z',
          '2026-01-03T00:00:00.000Z',
          1,
        ],
      );
      legacy.close();

      final db = await openMigratedDatabase();
      final article = await db.articlesDao.articleById('article-v5');

      expect(article, isNotNull);
      expect(article!.author, 'Legacy Author');
      expect(article.description, 'Legacy description');
      expect(article.hostname, 'example.com');
      expect(article.language, 'en');
      expect(article.readingProgress, 0.35);
      expect(article.isFinished, isTrue);
      final htmlFile = File(
        p.join(
          documentsDirectory.path,
          'articles',
          'article-v5',
          'content.html',
        ),
      );
      expect(await htmlFile.readAsString(), '<p>Preserved body</p>');
    },
  );

  test('migrates v6 absolute content and cover paths', () async {
    final oldArticlesDirectory = Directory(
      p.join(documentsDirectory.path, 'articles'),
    );
    final oldCoversDirectory = Directory(
      p.join(documentsDirectory.path, 'article_covers'),
    );
    await oldArticlesDirectory.create();
    await oldCoversDirectory.create();
    final oldContent = File(
      p.join(oldArticlesDirectory.path, 'article-v6.html'),
    );
    final oldCover = File(p.join(oldCoversDirectory.path, 'article-v6.jpg'));
    await oldContent.writeAsString('<p>Legacy file</p>');
    await oldCover.writeAsBytes([0xff, 0xd8, 0xff, 0xd9]);

    final legacy = _createLegacyDatabase(databaseFile, version: 6);
    _insertFileBackedArticle(
      legacy,
      id: 'article-v6',
      contentPath: oldContent.path,
      coverPath: oldCover.path,
      progress: 1.7,
    );
    legacy.close();

    final db = await openMigratedDatabase();
    final article = await db.articlesDao.articleById('article-v6');

    expect(article, isNotNull);
    expect(article!.contentPath, 'content.html');
    expect(article.coverImagePath, 'article-v6.jpg');
    expect(article.readingProgress, 1.0);
    expect(
      await File(
        p.join(
          documentsDirectory.path,
          'articles',
          'article-v6',
          'content.html',
        ),
      ).readAsString(),
      '<p>Legacy file</p>',
    );
    expect(
      await File(
        p.join(
          documentsDirectory.path,
          'articles',
          'article-v6',
          'article-v6.jpg',
        ),
      ).readAsBytes(),
      [0xff, 0xd8, 0xff, 0xd9],
    );
  });

  test('migrates v12 metadata, position, and existing article files', () async {
    final articleDirectory = Directory(
      p.join(documentsDirectory.path, 'articles', 'article-v12'),
    );
    await articleDirectory.create(recursive: true);
    await File(
      p.join(articleDirectory.path, 'content.html'),
    ).writeAsString('<p>Current layout</p>');

    final legacy = _createLegacyDatabase(databaseFile, version: 12);
    _insertFileBackedArticle(
      legacy,
      id: 'article-v12',
      contentPath: 'content.html',
      progress: 0.42,
      currentCfi: 'epubcfi(/6/4)',
    );
    legacy.close();

    final db = await openMigratedDatabase();
    final article = await db.articlesDao.articleById('article-v12');

    expect(article, isNotNull);
    expect(article!.currentCfi, 'epubcfi(/6/4)');
    expect(article.readingProgress, 0.42);
    expect(article.author, 'Author');
    expect(article.description, 'Description');
    expect(article.imageUrl, 'https://example.com/cover.jpg');
    expect(
      await db
          .customSelect(
            "SELECT COUNT(*) AS count FROM sqlite_master "
            "WHERE type = 'table' AND name = 'articles_table_legacy'",
          )
          .map((row) => row.read<int>('count'))
          .getSingle(),
      0,
    );
  });

  test(
    'preserves legacy rows when the documents directory is unavailable',
    () async {
      final legacy = _createLegacyDatabase(databaseFile, version: 12);
      _insertFileBackedArticle(
        legacy,
        id: 'article-without-directory',
        contentPath: '/old/container/content.html',
        progress: 0.2,
      );
      legacy.close();

      final db = await openMigratedDatabase(
        documentsDirectoryProvider: () =>
            Future<Directory>.error(StateError('Documents unavailable')),
      );
      final article = await db.articlesDao.articleById(
        'article-without-directory',
      );

      expect(article, isNotNull);
      expect(article!.contentPath, 'content.html');
      expect(article.readingProgress, 0.2);
    },
  );
}

sqlite.Database _createLegacyDatabase(File file, {required int version}) {
  final database = sqlite.sqlite3.open(file.path);
  _createSharedLegacyTables(database);
  if (version <= 5) {
    database.execute('''
      CREATE TABLE articles_table (
        id TEXT NOT NULL PRIMARY KEY,
        title TEXT NOT NULL,
        site_name TEXT,
        url TEXT NOT NULL,
        cleaned_html TEXT NOT NULL,
        cover_image_url TEXT,
        byline TEXT,
        excerpt TEXT,
        published_time TEXT,
        lang TEXT,
        text_length INTEGER NOT NULL DEFAULT 0,
        estimated_word_count INTEGER NOT NULL DEFAULT 0,
        current_scroll_offset REAL NOT NULL DEFAULT 0.0,
        added_at TEXT NOT NULL,
        last_opened_at TEXT,
        is_finished INTEGER NOT NULL DEFAULT 0
      )
    ''');
  } else {
    database.execute('''
      CREATE TABLE articles_table (
        id TEXT NOT NULL PRIMARY KEY,
        title TEXT NOT NULL,
        site_name TEXT,
        url TEXT NOT NULL,
        content_path TEXT NOT NULL,
        cover_image_url TEXT,
        cover_image_path TEXT,
        byline TEXT,
        excerpt TEXT,
        published_time TEXT,
        lang TEXT,
        text_length INTEGER NOT NULL DEFAULT 0,
        estimated_word_count INTEGER NOT NULL DEFAULT 0,
        current_scroll_offset REAL NOT NULL DEFAULT 0.0,
        added_at TEXT NOT NULL,
        last_opened_at TEXT,
        is_finished INTEGER NOT NULL DEFAULT 0
        ${version >= 12 ? ', current_cfi TEXT' : ''}
      )
    ''');
  }
  database.execute('PRAGMA user_version = $version');
  return database;
}

void _createSharedLegacyTables(sqlite.Database database) {
  database.execute(
    'CREATE TABLE books_table (id TEXT PRIMARY KEY, format TEXT NOT NULL)',
  );
  database.execute(
    'CREATE TABLE highlights_table (id TEXT PRIMARY KEY, source_id TEXT)',
  );
  database.execute(
    'CREATE TABLE flashcards_table (id TEXT PRIMARY KEY, deck_id TEXT)',
  );
  database.execute(
    'CREATE TABLE dictionary_table (id TEXT PRIMARY KEY, source_id TEXT)',
  );
  database.execute('''
    CREATE TABLE review_items_table (
      item_id TEXT PRIMARY KEY,
      item_type TEXT,
      source_id TEXT,
      next_review_at TEXT
    )
  ''');
}

void _insertFileBackedArticle(
  sqlite.Database database, {
  required String id,
  required String contentPath,
  required double progress,
  String? coverPath,
  String? currentCfi,
}) {
  final hasCurrentCfi = currentCfi != null;
  database.execute(
    '''
      INSERT INTO articles_table (
        id, title, site_name, url, content_path, cover_image_url,
        cover_image_path, byline, excerpt, published_time, lang, text_length,
        estimated_word_count, current_scroll_offset, added_at, last_opened_at,
        is_finished${hasCurrentCfi ? ', current_cfi' : ''}
      ) VALUES (
        ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
        ${hasCurrentCfi ? ', ?' : ''}
      )
    ''',
    [
      id,
      'File-backed article',
      'Example',
      'https://example.com/story',
      contentPath,
      'https://example.com/cover.jpg',
      coverPath,
      'Author',
      'Description',
      '2026-01-01T00:00:00.000Z',
      'en',
      100,
      20,
      progress,
      '2026-01-02T00:00:00.000Z',
      null,
      0,
      if (hasCurrentCfi) currentCfi,
    ],
  );
}
