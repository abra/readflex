// Dependency assembly: creates and wires all application-wide dependencies.
//
// Separates "what to create" from "how to launch" (starter.dart).
// composeDependencies() can be called independently in tests
// with substituted implementations.

import 'dart:io';

import 'package:article_extraction_service/article_extraction_service.dart';
import 'package:article_repository/article_repository.dart';
import 'package:book_repository/book_repository.dart';
import 'package:collection_repository/collection_repository.dart';
import 'package:connectivity_service/connectivity_service.dart';
import 'package:highlight_repository/highlight_repository.dart';
import 'package:local_storage/local_storage.dart';
import 'package:monitoring/monitoring.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:reader_server/reader_server.dart';
import 'package:readflex/app/config/application_config.dart';
import 'package:readflex/app/dependency_container.dart';
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
///
// TODO: replace NoopErrorReporter with real implementation (e.g. Sentry).
Future<ErrorReportingService> createErrorReporter(
  ApplicationConfig config,
) async {
  const errorReporter = NoopErrorReporter();
  if (config.enableSentry) {
    await errorReporter.initialize();
  }
  return errorReporter;
}

/// A place where Application-Wide dependencies are initialized.
///
/// Application-Wide dependencies are dependencies that have a global scope,
/// used in the entire application and have a lifetime that is the same as the application.
/// Composes dependencies and returns the result of composition.
Future<CompositionResult> composeDependencies({
  required ApplicationConfig config,
  required Logger logger,
  required ErrorReportingService errorReporter,
}) async {
  final stopwatch = Stopwatch()..start();

  logger.info('Initializing dependencies...');

  final dependencies = await createDependenciesContainer(
    config,
    logger,
    errorReporter,
  );

  stopwatch.stop();
  logger.info(
    'Dependencies initialized successfully in ${stopwatch.elapsedMilliseconds} ms.',
  );

  return CompositionResult(
    dependencies: dependencies,
    millisecondsSpent: stopwatch.elapsedMilliseconds,
  );
}

class CompositionResult {
  const CompositionResult({
    required this.dependencies,
    required this.millisecondsSpent,
  });

  final DependenciesContainer dependencies;
  final int millisecondsSpent;

  @override
  String toString() =>
      'CompositionResult('
      'dependencies: $dependencies, '
      'millisecondsSpent: $millisecondsSpent'
      ')';
}

/// Creates the initialized [DependenciesContainer].
Future<DependenciesContainer> createDependenciesContainer(
  ApplicationConfig config,
  Logger logger,
  ErrorReportingService errorReporter,
) async {
  final packageInfo = await PackageInfo.fromPlatform();

  // ─── Database ───
  final database = AppDatabase();

  // ─── Filesystem layout ───
  final documentsDir = await getApplicationDocumentsDirectory();
  final booksDir = Directory(p.join(documentsDir.path, 'books'));
  final articlesDir = Directory(p.join(documentsDir.path, 'articles'));
  final readerAssetsDir = Directory(p.join(documentsDir.path, 'reader_assets'));

  final readerServer = ReaderServer(
    assetsDirectory: readerAssetsDir,
    logger: logger,
  );

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
  final collectionRepository = CollectionRepository(database: database);
  final highlightRepository = HighlightRepository(database: database);

  // ─── Preferences ───
  final preferencesService = await PreferencesService.create(
    supportedCodes: config.supportedLocaleCodes,
  );

  final connectivityService = await ConnectivityPlusService.create();
  final screenControlService = WakelockScreenControlService();
  final articleExtractionService = TrafilaturaArticleExtractionService(
    baseUri: Uri.parse(config.articleCleanerBaseUrl),
    apiKey: config.articleCleanerApiKey.isEmpty
        ? null
        : config.articleCleanerApiKey,
  );

  return DependenciesContainer(
    logger: logger,
    config: config,
    errorReporter: errorReporter,
    packageInfo: packageInfo,
    preferencesService: preferencesService,
    articleExtractionService: articleExtractionService,
    articleRepository: articleRepository,
    bookRepository: bookRepository,
    collectionRepository: collectionRepository,
    highlightRepository: highlightRepository,
    connectivityService: connectivityService,
    screenControlService: screenControlService,
    readerServer: readerServer,
  );
}
