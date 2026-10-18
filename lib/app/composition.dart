// Dependency assembly: creates and wires all application-wide dependencies.
//
// Separates "what to create" from "how to launch" (starter.dart).
// Uses concrete platform/storage implementations; bootstrap tests substitute
// this factory as a whole rather than initializing production resources.

import 'dart:io';

import 'package:article_extraction_service/article_extraction_service.dart';
import 'package:article_repository/article_repository.dart';
import 'package:book_repository/book_repository.dart';
import 'package:collection_repository/collection_repository.dart';
import 'package:connectivity_service/connectivity_service.dart';
import 'package:contextual_translation_service/contextual_translation_service.dart';
import 'package:dictionary_service/dictionary_service.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:highlight_repository/highlight_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:local_storage/local_storage.dart';
import 'package:monitoring/monitoring.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:reader_server/reader_server.dart';
import 'package:readflex/app/config/application_config.dart';
import 'package:readflex/app/dependency_container.dart';
import 'package:readflex/app/resource_disposer.dart';
import 'package:screen_control_service/screen_control_service.dart';

/// Creates the [Logger] instance and attaches any provided observers.
Logger createAppLogger({List<LogObserver> observers = const []}) {
  final logger = Logger();
  for (final observer in observers) {
    logger.addObserver(observer);
  }
  return logger;
}

/// Creates the [ErrorReportingService] instance.
Future<ErrorReportingService> createErrorReporter(
  ApplicationConfig config,
) async {
  if (config.enableGlitchTip) {
    final errorReporter = GlitchTipErrorReporter(
      dsn: config.glitchTipDsn,
      environment: config.environment.name,
      tracesSampleRate: config.glitchTipTracesSampleRate,
    );
    await errorReporter.initialize();
    return errorReporter;
  }

  return const NoopErrorReporter();
}

/// Creates the `dart:io` client behind every Readflex API service.
///
/// The connect timeout lets an unreachable host fail as a network error, so
/// Translate reaches its offline fallback without waiting out the 45 s request
/// timeout. The default 15 s idle timeout stays: the backend's keep-alive is
/// unknown, and a longer one risks reusing a socket the server already closed.
@visibleForTesting
HttpClient createBackendHttpClient() =>
    HttpClient()..connectionTimeout = const Duration(seconds: 10);

/// Wires the Readflex API services to one [backendHttpClient], so they reuse
/// its connections to the shared API host.
///
/// [resources] takes ownership of the client and of the services. The client
/// is registered first, so it closes after every service that uses it.
@visibleForTesting
({
  ArticleExtractionService articleExtractionService,
  ContextualTranslationService contextualTranslationService,
  DictionaryLookupService dictionaryLookupService,
})
createBackendServices({
  required ApplicationConfig config,
  required ResourceDisposer resources,
  required http.Client backendHttpClient,
  required OfflineContextualTranslationService offlineTranslationService,
}) {
  resources.add('backendHttpClient.close', backendHttpClient.close);
  final developmentApiKey = config.developmentApiKey;
  final apiKey = developmentApiKey.isEmpty ? null : developmentApiKey;

  // Untrusted article pages use the extraction service's own pinned client.
  final articleExtractionService = TrafilaturaArticleExtractionService(
    baseUri: Uri.parse(config.articleCleanerBaseUrl),
    httpClient: backendHttpClient,
    apiKey: apiKey,
  );
  resources.add(
    'articleExtractionService.dispose',
    articleExtractionService.dispose,
  );
  final contextualTranslationService = ContextualTranslationCoordinator(
    remoteService: RemoteContextualTranslationService(
      baseUri: Uri.parse(config.contextualTranslationBaseUrl),
      httpClient: backendHttpClient,
      apiKey: apiKey,
    ),
    offlineService: offlineTranslationService,
  );
  resources.add(
    'contextualTranslationService.dispose',
    contextualTranslationService.dispose,
  );
  final dictionaryLookupService = RemoteDictionaryLookupService(
    baseUri: Uri.parse(config.dictionaryBaseUrl),
    httpClient: backendHttpClient,
    apiKey: apiKey,
  );
  resources.add(
    'dictionaryLookupService.dispose',
    dictionaryLookupService.dispose,
  );
  return (
    articleExtractionService: articleExtractionService,
    contextualTranslationService: contextualTranslationService,
    dictionaryLookupService: dictionaryLookupService,
  );
}

/// Creates dependencies, rolling back partial construction on failure.
Future<DependenciesContainer> composeDependencies({
  required ApplicationConfig config,
  required Logger logger,
  required ErrorReportingService errorReporter,
}) async {
  final stopwatch = Stopwatch()..start();

  logger.info('Initializing dependencies...');

  final dependencies = await _createDependenciesContainer(
    config,
    logger,
    errorReporter,
  );

  stopwatch.stop();
  logger.info(
    'Dependencies initialized successfully in ${stopwatch.elapsedMilliseconds} ms.',
  );

  return dependencies;
}

/// Creates the initialized [DependenciesContainer].
Future<DependenciesContainer> _createDependenciesContainer(
  ApplicationConfig config,
  Logger logger,
  ErrorReportingService errorReporter,
) async {
  // Monitoring belongs to the retry loop until startup succeeds. Only the
  // running app closes it; failed attempts release their own resources.
  final resources = ResourceDisposer(logger: logger)
    ..add('logger.destroy', logger.destroy, disposeOnRollback: false)
    ..add(
      'errorReporter.close',
      errorReporter.close,
      disposeOnRollback: false,
    );

  try {
    final packageInfo = await PackageInfo.fromPlatform();

    // ─── Database ───
    final database = AppDatabase();
    resources.add('database.close', database.close);

    // ─── Filesystem layout ───
    final documentsDir = await getApplicationDocumentsDirectory();
    final booksDir = Directory(p.join(documentsDir.path, 'books'));
    final articlesDir = Directory(p.join(documentsDir.path, 'articles'));
    final readerAssetsDir = Directory(
      p.join(documentsDir.path, 'reader_assets'),
    );

    final readerServer = ReaderServer(
      assetsDirectory: readerAssetsDir,
      booksDirectory: booksDir,
      articlesDirectory: articlesDir,
      logger: logger,
    );
    resources.add('readerServer.stop', readerServer.stop);

    // ─── Repositories ───
    final bookRepository = BookRepository(
      database: database,
      booksDirectory: booksDir,
      logger: logger,
    );
    final articleRepository = ArticleRepository(
      database: database,
      articlesDirectory: articlesDir,
      logger: logger,
    );
    resources.add('articleRepository.dispose', articleRepository.dispose);
    final collectionRepository = CollectionRepository(database: database);
    final highlightRepository = HighlightRepository(database: database);

    // ─── Preferences ───
    final preferencesService = await PreferencesService.create(
      supportedCodes: config.supportedLocaleCodes,
    );
    resources.add('preferencesService.dispose', preferencesService.dispose);

    final connectivityService = await ConnectivityPlusService.create();
    resources.add('connectivityService.dispose', connectivityService.dispose);
    final screenControlService = WakelockScreenControlService();
    final backendServices = createBackendServices(
      config: config,
      resources: resources,
      backendHttpClient: IOClient(createBackendHttpClient()),
      offlineTranslationService: MlKitOfflineTranslationService(),
    );
    final systemDictionaryService = PlatformSystemDictionaryService();

    return DependenciesContainer(
      logger: logger,
      config: config,
      errorReporter: errorReporter,
      packageInfo: packageInfo,
      preferencesService: preferencesService,
      articleExtractionService: backendServices.articleExtractionService,
      articleRepository: articleRepository,
      bookRepository: bookRepository,
      collectionRepository: collectionRepository,
      highlightRepository: highlightRepository,
      connectivityService: connectivityService,
      contextualTranslationService:
          backendServices.contextualTranslationService,
      systemDictionaryService: systemDictionaryService,
      dictionaryLookupService: backendServices.dictionaryLookupService,
      screenControlService: screenControlService,
      readerServer: readerServer,
      database: database,
      resourceDisposer: resources,
    );
  } on Object {
    await resources.dispose(rollback: true);
    rethrow;
  }
}
