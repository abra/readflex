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
    'v22 comics keep legacy indexing and saved anchors after upgrade',
    () async {
      final current = AppDatabase.forTesting(NativeDatabase(databaseFile));
      await current.customSelect('SELECT 1').getSingle();
      await current.customStatement(
        'ALTER TABLE books_table DROP COLUMN comic_page_order_version',
      );
      await current.customStatement(
        'ALTER TABLE bookmarks_table DROP COLUMN anchor_version',
      );
      await current.customStatement(
        "INSERT INTO books_table (id, title, format, file_path, added_at, current_cfi) VALUES ('comic', 'Comic', 'cbz', 'book.cbz', '2026-01-01', 'epubcfi(/6/4)')",
      );
      await current.customStatement('PRAGMA user_version = 22');
      await current.close();
      final migrated = await openMigratedDatabase();
      final row = (await migrated.booksDao.bookById('comic'))!;
      expect(row.comicPageOrderVersion, 0);
      expect(row.currentCfi, 'epubcfi(/6/4)');
    },
  );

  test('v24 bookmarks gain an empty anchor version', () async {
    final current = AppDatabase.forTesting(NativeDatabase(databaseFile));
    await current.customSelect('SELECT 1').getSingle();
    await current.customStatement(
      'ALTER TABLE bookmarks_table DROP COLUMN anchor_version',
    );
    await current.customStatement('''
      INSERT INTO bookmarks_table (
        id, source_id, source_type, cfi, content, progress, chapter_title,
        anchor_exact, anchor_prefix, anchor_suffix, anchor_section_index,
        anchor_section_page, created_at
      ) VALUES ('b', 'book', 'book', 'epubcfi(/6/2!/4/2,/1:0,/1:9)',
        'Page text', 0.25, 'One', 'quote', 'before', 'after', 0, 3,
        '2026-01-01T00:00:00.000')
    ''');
    await current.customStatement('PRAGMA user_version = 24');
    await current.close();

    final migrated = await openMigratedDatabase();
    final row = await migrated
        .customSelect("SELECT * FROM bookmarks_table WHERE id = 'b'")
        .getSingle();
    expect(row.readNullable<int>('anchor_version'), isNull);
    expect(row.read<String>('cfi'), 'epubcfi(/6/2!/4/2,/1:0,/1:9)');
    expect(row.read<String>('anchor_exact'), 'quote');
    expect(row.read<int>('anchor_section_index'), 0);
    expect(row.read<int>('anchor_section_page'), 3);
    expect(row.read<double>('progress'), 0.25);

    await migrated.customStatement(
      "UPDATE bookmarks_table SET anchor_version = 2 WHERE id = 'b'",
    );
    final updated = await migrated
        .customSelect("SELECT anchor_version FROM bookmarks_table")
        .getSingle();
    expect(updated.read<int>('anchor_version'), 2);
  });

  test('v23 articles move their text after every other column', () async {
    final current = AppDatabase.forTesting(NativeDatabase(databaseFile));
    await current.customSelect('SELECT 1').getSingle();
    await current.customStatement(
      'ALTER TABLE bookmarks_table DROP COLUMN anchor_version',
    );
    await current.customStatement('DROP TABLE articles_table');
    await current.customStatement('''
      CREATE TABLE articles_table (
        id TEXT NOT NULL PRIMARY KEY,
        title TEXT NOT NULL,
        url TEXT NOT NULL,
        resolved_url TEXT,
        canonical_url TEXT,
        author TEXT,
        site_name TEXT,
        hostname TEXT,
        description TEXT,
        image_url TEXT,
        cover_image_path TEXT,
        language TEXT,
        content_path TEXT NOT NULL,
        plain_text TEXT NOT NULL DEFAULT '',
        text_length INTEGER NOT NULL DEFAULT 0,
        estimated_word_count INTEGER NOT NULL DEFAULT 0,
        current_cfi TEXT,
        reading_progress REAL NOT NULL DEFAULT 0.0,
        added_at TEXT NOT NULL,
        last_opened_at TEXT,
        is_finished INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await current.customStatement(
      'CREATE INDEX idx_articles_last_opened '
      'ON articles_table (last_opened_at, added_at)',
    );
    final text = 'word ' * 10000;
    await current.customStatement(
      '''
      INSERT INTO articles_table (
        id, title, url, author, site_name, hostname, language, content_path,
        plain_text, text_length, estimated_word_count, current_cfi,
        reading_progress, added_at, last_opened_at, is_finished
      ) VALUES ('a', 'Title', 'https://example.com/a', 'Author', 'Example',
        'example.com', 'en', 'content.html', ?, 50000, 10000, 'cfi', 0.25,
        '2026-01-01', '2026-01-02', 1)
    ''',
      [text],
    );
    await current.customStatement('PRAGMA user_version = 23');
    await current.close();

    final migrated = await openMigratedDatabase();
    final columns = await migrated
        .customSelect('PRAGMA table_info(articles_table)')
        .map((row) => row.read<String>('name'))
        .get();
    expect(columns.last, 'plain_text');
    expect(columns, hasLength(21));

    final article = (await migrated.articlesDao.articleById('a'))!;
    expect(article.plainText, text);
    expect(article.textLength, 50000);
    expect(article.estimatedWordCount, 10000);
    expect(article.currentCfi, 'cfi');
    expect(article.readingProgress, 0.25);
    expect(article.lastOpenedAt, '2026-01-02');
    expect(article.isFinished, isTrue);
    expect(article.language, 'en');

    final plan = await migrated
        .customSelect(
          'EXPLAIN QUERY PLAN SELECT id FROM articles_table '
          'ORDER BY last_opened_at DESC, added_at DESC',
        )
        .map((row) => row.read<String>('detail'))
        .get();
    expect(plan.single, contains('idx_articles_last_opened'));
  });

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
