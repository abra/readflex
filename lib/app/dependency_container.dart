// DI container: holds all application-wide dependencies as a plain data class.
//
// Passed down the widget tree via DependenciesScope instead of using global
// singletons or a service locator. This keeps dependencies explicit and makes
// them easy to substitute in tests via TestDependenciesContainer.

import 'package:article_extraction_service/article_extraction_service.dart';
import 'package:article_repository/article_repository.dart';
import 'package:book_repository/book_repository.dart';
import 'package:collection_repository/collection_repository.dart';
import 'package:connectivity_service/connectivity_service.dart';
import 'package:highlight_repository/highlight_repository.dart';
import 'package:monitoring/monitoring.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:reader_server/reader_server.dart';
import 'package:readflex/app/config/application_config.dart';
import 'package:screen_control_service/screen_control_service.dart';

/// Container for global dependencies.
class DependenciesContainer {
  const DependenciesContainer({
    required this.logger,
    required this.config,
    required this.errorReporter,
    required this.packageInfo,
    required this.preferencesService,
    required this.articleExtractionService,
    required this.articleRepository,
    required this.bookRepository,
    required this.collectionRepository,
    required this.highlightRepository,
    required this.connectivityService,
    required this.screenControlService,
    required this.readerServer,
  });

  final Logger logger;
  final ApplicationConfig config;
  final ErrorReportingService errorReporter;
  final PackageInfo packageInfo;
  final PreferencesService preferencesService;
  final ArticleExtractionService articleExtractionService;
  final ArticleRepository articleRepository;
  final BookRepository bookRepository;
  final CollectionRepository collectionRepository;
  final HighlightRepository highlightRepository;
  final ConnectivityService connectivityService;
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
    try {
      articleExtractionService.dispose();
    } catch (e, st) {
      logger.warn(
        'articleExtractionService.dispose failed',
        error: e,
        stackTrace: st,
      );
    }
    try {
      articleRepository.dispose();
    } catch (e, st) {
      logger.warn('articleRepository.dispose failed', error: e, stackTrace: st);
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
