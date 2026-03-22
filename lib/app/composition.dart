// Dependency assembly: creates and wires all application-wide dependencies.
//
// Separates "what to create" from "how to launch" (starter.dart).
// composeDependencies() can be called independently in tests
// with substituted implementations.

import 'package:ai_service/ai_service.dart';
import 'package:article_parser/article_parser.dart';
import 'package:article_repository/article_repository.dart';
import 'package:auth_service/auth_service.dart';
import 'package:book_repository/book_repository.dart';
import 'package:connectivity_service/connectivity_service.dart';
import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:flashcard_repository/flashcard_repository.dart';
import 'package:highlight_repository/highlight_repository.dart';
import 'package:local_storage/local_storage.dart';
import 'package:monitoring/monitoring.dart';
import 'package:notification_service/notification_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:readflex/app/config/application_config.dart';
import 'package:readflex/app/dependency_container.dart';
import 'package:subscription_service/subscription_service.dart';
import 'package:translation_service/translation_service.dart';

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
/// Replace [NoopErrorReporter] with a real implementation (e.g. Crashlytics)
/// from packages/monitoring when ready.
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

final class CompositionResult {
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
  final db = AppDatabase();

  // ─── Repositories ───
  final articleRepository = ArticleRepository(articlesDao: db.articlesDao);
  final bookRepository = BookRepository(booksDao: db.booksDao);
  final highlightRepository = HighlightRepository(
    highlightsDao: db.highlightsDao,
  );
  final flashcardRepository = FlashcardRepository(
    flashcardsDao: db.flashcardsDao,
  );
  final dictionaryRepository = DictionaryRepository(
    dictionaryDao: db.dictionaryDao,
  );

  // ─── Preferences ───
  final preferencesService = await PreferencesService.create(
    supportedCodes: ['en', 'ru'],
  );

  // ─── Services (stubs for now) ───
  final authService = NoopAuthService();
  const articleParser = NoopArticleParser();
  const translationService = NoopTranslationService();
  const aiService = NoopAiService();
  const subscriptionService = NoopSubscriptionService();
  final connectivityService = NoopConnectivityService();
  const notificationService = NoopNotificationService();

  return DependenciesContainer(
    logger: logger,
    config: config,
    errorReporter: errorReporter,
    packageInfo: packageInfo,
    preferencesService: preferencesService,
    authService: authService,
    articleRepository: articleRepository,
    bookRepository: bookRepository,
    highlightRepository: highlightRepository,
    flashcardRepository: flashcardRepository,
    dictionaryRepository: dictionaryRepository,
    articleParser: articleParser,
    translationService: translationService,
    aiService: aiService,
    subscriptionService: subscriptionService,
    connectivityService: connectivityService,
    notificationService: notificationService,
  );
}
