// DI container: holds all application-wide dependencies as a plain data class.
//
// Passed down the widget tree via DependenciesScope instead of using global
// singletons or a service locator. This keeps dependencies explicit and makes
// them easy to substitute in tests via TestDependenciesContainer.

import 'package:ai_service/ai_service.dart';
import 'package:article_parser/article_parser.dart';
import 'package:article_repository/article_repository.dart';
import 'package:auth_service/auth_service.dart';
import 'package:book_repository/book_repository.dart';
import 'package:connectivity_service/connectivity_service.dart';
import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:flashcard_repository/flashcard_repository.dart';
import 'package:highlight_repository/highlight_repository.dart';
import 'package:monitoring/monitoring.dart';
import 'package:notification_service/notification_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:readflex/app/config/application_config.dart';
import 'package:subscription_service/subscription_service.dart';
import 'package:translation_service/translation_service.dart';

/// Container for global dependencies.
class DependenciesContainer {
  const DependenciesContainer({
    required this.logger,
    required this.config,
    required this.errorReporter,
    required this.packageInfo,
    required this.preferencesService,
    required this.authService,
    required this.articleRepository,
    required this.bookRepository,
    required this.highlightRepository,
    required this.flashcardRepository,
    required this.dictionaryRepository,
    required this.articleParser,
    required this.translationService,
    required this.aiService,
    required this.subscriptionService,
    required this.connectivityService,
    required this.notificationService,
  });

  final Logger logger;
  final ApplicationConfig config;
  final ErrorReportingService errorReporter;
  final PackageInfo packageInfo;
  final PreferencesService preferencesService;
  final AuthService authService;
  final ArticleRepository articleRepository;
  final BookRepository bookRepository;
  final HighlightRepository highlightRepository;
  final FlashcardRepository flashcardRepository;
  final DictionaryRepository dictionaryRepository;
  final ArticleParser articleParser;
  final TranslationService translationService;
  final AiService aiService;
  final SubscriptionService subscriptionService;
  final ConnectivityService connectivityService;
  final NotificationService notificationService;
}

/// A special version of [DependenciesContainer] that is used in tests.
///
/// In order to use [DependenciesContainer] in tests, it is needed to
/// extend this class and provide the dependencies that are needed for the test.
base class TestDependenciesContainer implements DependenciesContainer {
  const TestDependenciesContainer();

  @override
  Object noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      'The test tries to access ${invocation.memberName} dependency, but '
      'it was not provided. Please provide the dependency in the test. '
      'You can do it by extending this class and providing the dependency.',
    );
  }
}
