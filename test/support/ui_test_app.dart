import 'dart:io';

import 'package:article_repository/article_repository.dart';
import 'package:book_repository/book_repository.dart';
import 'package:collection_repository/collection_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:highlight_repository/highlight_repository.dart';
import 'package:local_storage/local_storage.dart';
import 'package:monitoring/monitoring.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:reader_server/reader_server.dart';
import 'package:reader_webview/reader_webview.dart';
import 'package:readflex/app/composition.dart';
import 'package:readflex/app/config/application_config.dart';
import 'package:readflex/app/dependency_container.dart';
import 'package:readflex/app/root_context.dart';
import 'package:readflex/app/resource_disposer.dart';
import 'package:screen_control_service/screen_control_service.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'reading_fixture.dart';
import 'ui_test_services.dart';

/// Runs the production root/router against isolated storage. Never calls
/// composeDependencies(), reads API keys, or opens the user's application DB.
final class UiTestApp {
  UiTestApp._(this.directory, this._previousPreferencesPlatform) {
    _resources
      ..add('logger', logger.destroy)
      ..add('directory', () => directory.delete(recursive: true))
      ..add('preferences platform', () {
        SharedPreferencesAsyncPlatform.instance = _previousPreferencesPlatform;
      })
      ..add('connectivity', connectivityService.dispose);
  }

  final Directory directory;
  final SharedPreferencesAsyncPlatform? _previousPreferencesPlatform;
  final logger = Logger();
  final config = const ApplicationConfig();
  final errorReporter = const NoopErrorReporter();
  final articleExtractionService = FixtureArticleExtraction();
  final contextualTranslationService = FixtureTranslation();
  final dictionaryLookupService = FixtureDictionary();
  final systemDictionaryService = FixtureSystemDictionary();
  final connectivityService = FixtureConnectivity();
  final screenControlService = const NoopScreenControlService();
  late final _resources = ResourceDisposer(logger: logger);
  late final AppDatabase database;
  late final PreferencesService preferencesService;
  late final CountingBookRepository bookRepository;
  late final RecordingArticleRepository articleRepository;
  late final CollectionRepository collectionRepository;
  late final HighlightRepository highlightRepository;
  late final ReaderServer readerServer;
  Book? book;

  late final dependencies = DependenciesContainer(
    logger: logger,
    config: config,
    errorReporter: errorReporter,
    packageInfo: PackageInfo(
      appName: 'Readflex Tests',
      packageName: 'readflex.tests',
      version: '1',
      buildNumber: '1',
    ),
    preferencesService: preferencesService,
    articleExtractionService: articleExtractionService,
    articleRepository: articleRepository,
    bookRepository: bookRepository,
    collectionRepository: collectionRepository,
    highlightRepository: highlightRepository,
    connectivityService: connectivityService,
    contextualTranslationService: contextualTranslationService,
    systemDictionaryService: systemDictionaryService,
    dictionaryLookupService: dictionaryLookupService,
    screenControlService: screenControlService,
    readerServer: readerServer,
    database: database,
    resourceDisposer: _resources,
  );

  static Future<UiTestApp> create({
    bool withBook = true,
    bool nativeReader = false,
    bool onboardingCompleted = true,
  }) async {
    final previous = SharedPreferencesAsyncPlatform.instance;
    final app = UiTestApp._(
      await Directory.systemTemp.createTemp('readflex-ui-'),
      previous,
    );
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    try {
      app.database = AppDatabase.forTesting(
        NativeDatabase.memory(),
        documentsDirectoryProvider: () async => app.directory,
      );
      app._resources.add('database', app.database.close);
      app.preferencesService = await PreferencesService.create(
        supportedCodes: ['en', 'de', 'ar'],
      );
      app._resources.add('preferences', app.preferencesService.dispose);
      await app.preferencesService.update(
        (p) => p.copyWith(
          onboardingCompleted: onboardingCompleted,
          locale: const Locale('en'),
          themeMode: ThemeMode.light,
          translationTargetLanguageCode: 'de',
        ),
      );
      final books = Directory('${app.directory.path}/books');
      final articles = Directory('${app.directory.path}/articles');
      app.bookRepository = CountingBookRepository(
        database: app.database,
        booksDirectory: books,
      );
      app.articleRepository = RecordingArticleRepository(
        database: app.database,
        articlesDirectory: articles,
      );
      app._resources.add('article repository', app.articleRepository.dispose);
      app.collectionRepository = CollectionRepository(database: app.database);
      app.highlightRepository = HighlightRepository(database: app.database);
      app.readerServer = ReaderServer(
        assetsDirectory: Directory('${app.directory.path}/reader_assets'),
        booksDirectory: books,
        articlesDirectory: articles,
        logger: app.logger,
      );
      app._resources.add('reader server', app.readerServer.stop);
      if (nativeReader) {
        await AssetExtractor(
          targetDirectory: app.readerServer.assetsDirectory,
          logger: app.logger,
        ).extractAll(version: 'ui-test');
        await app.readerServer.start();
      }
      if (withBook) {
        // Cover palette depends on the ID; random IDs make goldens unstable.
        const id = 'ui-fixture-book';
        final file = File('${books.path}/$id/book.fb2');
        await file.parent.create(recursive: true);
        await file.writeAsString(ReadingFixture.fb2);
        await app.database.booksDao.insertBook(
          BooksTableCompanion.insert(
            id: id,
            title: ReadingFixture.bookTitle,
            author: const Value('Readflex Tests'),
            filePath: 'book.fb2',
            format: BookFormat.fb2.name,
            addedAt: DateTime(2026).toIso8601String(),
          ),
        );
        app.book = await app.bookRepository.getBookById(id);
      }
      return app;
    } on Object {
      await app.dispose();
      rethrow;
    }
  }

  Widget get widget => RootContext(
    compositionResult: CompositionResult(
      dependencies: dependencies,
      millisecondsSpent: 0,
    ),
  );

  Future<void> dispose() => _resources.dispose();
}

class CountingBookRepository extends BookRepository {
  CountingBookRepository({
    required super.database,
    required super.booksDirectory,
  });
  int reads = 0;

  @override
  Future<List<Book>> getBooks({int? limit, int? offset}) {
    reads++;
    return super.getBooks(limit: limit, offset: offset);
  }
}

class RecordingArticleRepository extends ArticleRepository {
  RecordingArticleRepository({
    required super.database,
    required super.articlesDirectory,
  });
  Object? lastError;

  @override
  Future<Article> addExtractedArticle(ExtractedArticle extracted) async {
    try {
      return await super.addExtractedArticle(extracted);
    } catch (error) {
      lastError = error;
      rethrow;
    }
  }
}
