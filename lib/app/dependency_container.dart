// DI container: holds all application-wide dependencies as a plain data class.
//
// Passed down the widget tree via DependenciesScope instead of using global
// singletons or a service locator. This keeps dependencies explicit and makes
// them easy to substitute in tests via TestDependenciesContainer.

import 'package:ai_service/ai_service.dart';
import 'package:auth_service/auth_service.dart';
import 'package:book_repository/book_repository.dart';
import 'package:connectivity_service/connectivity_service.dart';
import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:flashcard_repository/flashcard_repository.dart';
import 'package:fsrs_repository/fsrs_repository.dart';
import 'package:highlight_repository/highlight_repository.dart';
import 'package:monitoring/monitoring.dart';
import 'package:notification_service/notification_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:reader_server/reader_server.dart';
import 'package:readflex/app/config/application_config.dart';
import 'package:screen_control_service/screen_control_service.dart';
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
    required this.bookRepository,
    required this.highlightRepository,
    required this.flashcardRepository,
    required this.dictionaryRepository,
    required this.fsrsRepository,
    required this.translationService,
    required this.aiService,
    required this.subscriptionService,
    required this.connectivityService,
    required this.notificationService,
    required this.screenControlService,
    required this.readerServer,
  });

  final Logger logger;
  final ApplicationConfig config;
  final ErrorReportingService errorReporter;
  final PackageInfo packageInfo;
  final PreferencesService preferencesService;
  final AuthService authService;
  final BookRepository bookRepository;
  final HighlightRepository highlightRepository;
  final FlashcardRepository flashcardRepository;
  final DictionaryRepository dictionaryRepository;
  final FsrsRepository fsrsRepository;
  final TranslationService translationService;
  final AiService aiService;
  final SubscriptionService subscriptionService;
  final ConnectivityService connectivityService;
  final NotificationService notificationService;
  final ScreenControlService screenControlService;
  final ReaderServer readerServer;

  /// Releases resources owned by the container — the local reader HTTP
  /// server and any other long-lived sockets/handles.
  ///
  /// Wired into a `WidgetsBindingObserver` for `AppLifecycleState.detached`
  /// so a long-running session doesn't leak sockets, and so the reader
  /// server's port is freed if the OS gives the process a chance to wind
  /// down before kill. Best-effort: if a `close()` throws, we swallow and
  /// continue with the rest — losing one socket is preferable to leaking
  /// the others because the first one panicked.
  Future<void> dispose() async {
    try {
      await readerServer.stop();
    } catch (e, st) {
      logger.warn('readerServer.stop failed', error: e, stackTrace: st);
    }
  }
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
