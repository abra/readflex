import 'package:monitoring/monitoring.dart';
import 'package:readflex/app/composition.dart';
import 'package:readflex/app/config/application_config.dart';
import 'package:readflex/app/dependency_container.dart';

typedef DependenciesFactory =
    Future<DependenciesContainer> Function({
      required ApplicationConfig config,
      required Logger logger,
      required ErrorReportingService errorReporter,
    });

/// Coordinates startup attempts while retaining monitoring across retries.
class AppBootstrap {
  AppBootstrap({
    required this.config,
    required this.logger,
    Future<ErrorReportingService> Function(ApplicationConfig) reporterFactory =
        createErrorReporter,
    DependenciesFactory dependenciesFactory = composeDependencies,
  }) : _reporterFactory = reporterFactory,
       _dependenciesFactory = dependenciesFactory;

  final ApplicationConfig config;
  final Logger logger;
  final Future<ErrorReportingService> Function(ApplicationConfig)
  _reporterFactory;
  final DependenciesFactory _dependenciesFactory;
  ErrorReportingService? _errorReporter;

  /// [onReady] takes ownership only after returning successfully. A failing
  /// factory cleans up partial construction; this method handles later failures.
  Future<void> run({
    required void Function(DependenciesContainer) onReady,
    required void Function(Object, StackTrace) onFailure,
  }) async {
    DependenciesContainer? pendingDependencies;
    try {
      config.validate();
      var reporter = _errorReporter;
      if (reporter == null) {
        reporter = await _reporterFactory(config);
        _errorReporter = reporter;
        logger.addObserver(ErrorReporterLogObserver(reporter));
      }
      final dependencies = await _dependenciesFactory(
        config: config,
        logger: logger,
        errorReporter: reporter,
      );
      pendingDependencies = dependencies;
      onReady(dependencies);
    } on Object catch (error, stackTrace) {
      await pendingDependencies?.disposeAfterBootstrapFailure();
      logger.error(
        'Initialization failed',
        error: error,
        stackTrace: stackTrace,
      );
      onFailure(error, stackTrace);
    }
  }
}
