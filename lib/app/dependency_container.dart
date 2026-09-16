// Holds application-wide dependencies and delegates cleanup to ResourceDisposer.
//
// Passed down the widget tree via DependenciesScope instead of using global
// singletons or a service locator. This keeps dependencies explicit and makes
// them easy to substitute in tests.

import 'package:article_extraction_service/article_extraction_service.dart';
import 'package:article_repository/article_repository.dart';
import 'package:book_repository/book_repository.dart';
import 'package:collection_repository/collection_repository.dart';
import 'package:connectivity_service/connectivity_service.dart';
import 'package:contextual_translation_service/contextual_translation_service.dart';
import 'package:dictionary_service/dictionary_service.dart';
import 'package:highlight_repository/highlight_repository.dart';
import 'package:local_storage/local_storage.dart';
import 'package:monitoring/monitoring.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:reader_server/reader_server.dart';
import 'package:readflex/app/config/application_config.dart';
import 'package:readflex/app/resource_disposer.dart';
import 'package:screen_control_service/screen_control_service.dart';

/// Container for global dependencies.
class DependenciesContainer {
  DependenciesContainer({
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
    required this.contextualTranslationService,
    required this.systemDictionaryService,
    required this.dictionaryLookupService,
    required this.screenControlService,
    required this.readerServer,
    required this.database,
    required ResourceDisposer resourceDisposer,
  }) : _resourceDisposer = resourceDisposer;

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
  final ContextualTranslationService contextualTranslationService;
  final SystemDictionaryService systemDictionaryService;
  final DictionaryLookupService dictionaryLookupService;
  final ScreenControlService screenControlService;
  final ReaderServer readerServer;
  final AppDatabase database;
  final ResourceDisposer _resourceDisposer;

  /// Releases all resources owned by the running application exactly once.
  Future<void> dispose() => _resourceDisposer.dispose();

  /// Releases resources created for an unsuccessful bootstrap attempt.
  ///
  /// The logger and error reporter belong to the retry loop and stay alive.
  Future<void> disposeAfterBootstrapFailure() =>
      _resourceDisposer.dispose(rollback: true);
}
