// Application bootstrap: error zone, Flutter binding initialization, runApp.
//
// Sets up runZonedGuarded to catch all unhandled async errors.
// Configures FlutterError.onError and platformDispatcher.onError so that
// errors at every level are routed to the logger.
// On initialization failure — shows a recovery screen instead of crashing.

import 'dart:async';

import 'package:dev_data/dev_data.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:monitoring/monitoring.dart';
import 'package:reader_webview/reader_webview.dart';
import 'package:readflex/app/bloc/app_bloc_observer.dart';
import 'package:readflex/app/bloc/bloc_transformer.dart';
import 'package:readflex/app/composition.dart';
import 'package:readflex/app/config/application_config.dart';
import 'package:readflex/app/root_context.dart';
import 'package:readflex/app/screens/initialization_failed_screen.dart';

const _traceBuilds = bool.fromEnvironment('READFLEX_TRACE_BUILDS');
const _profileBuilds = bool.fromEnvironment('READFLEX_PROFILE_BUILDS');
const _profileUserBuilds = bool.fromEnvironment(
  'READFLEX_PROFILE_USER_BUILDS',
);

/// Initializes dependencies and runs app.
Future<void> starter() async {
  const config = ApplicationConfig();

  final errorReporter = await createErrorReporter(config);

  final logger = createAppLogger(
    observers: [
      ErrorReporterLogObserver(errorReporter),
      if (!kReleaseMode) const PrintingLogObserver(logLevel: LogLevel.trace),
    ],
  );

  await runZonedGuarded(() async {
    // Ensure Flutter is initialized.
    WidgetsFlutterBinding.ensureInitialized();
    _configureBuildTracing(logger);

    // Configure global error interception.
    FlutterError.onError = logger.logFlutterError;
    WidgetsBinding.instance.platformDispatcher.onError =
        logger.logPlatformDispatcherError;

    // Setup bloc observer and transformer.
    Bloc.observer = AppBlocObserver(logger);
    Bloc.transformer = SequentialBlocTransformer<Object?>().transform;

    // Defined as a local function so it can pass itself as onRetryInitialization,
    // allowing the error screen to re-run the full initialization without
    // restarting the process.
    Future<void> composeAndRun() async {
      try {
        final compositionResult = await composeDependencies(
          config: config,
          logger: logger,
          errorReporter: errorReporter,
        );

        final deps = compositionResult.dependencies;

        // Extract WebView assets (foliate-js) to cache so the HTTP server
        // can serve them as plain files.
        // Re-extracts when the app version changes. In dev builds we always
        // force re-extract so local edits to foliate-js / reader assets are
        // picked up without bumping pubspec version.
        final assetExtractor = AssetExtractor(
          targetDirectory: deps.readerServer.assetsDirectory,
          logger: logger,
        );
        final assetVersion =
            '${deps.packageInfo.version}+${deps.packageInfo.buildNumber}';
        await assetExtractor.extractAll(
          version: assetVersion,
          force: config.isDev,
        );

        // Start the local HTTP server that serves book files to the
        // reader WebView.
        await deps.readerServer.start();

        // Dev-only seed: fills the Dictionary tab with a few entries
        // so the screen has something to render in development. Gated
        // on `config.isDev` so prod builds always start with an empty
        // dictionary.
        if (config.isDev) {
          await seedDictionary(
            dictionaryRepository: deps.dictionaryRepository,
            fsrsRepository: deps.fsrsRepository,
          );
        }

        runApp(RootContext(compositionResult: compositionResult));
      } on Object catch (e, stackTrace) {
        // Catches both Exception and Error (e.g. OutOfMemoryError),
        // ensuring no failure silently escapes during initialization.
        logger.error('Initialization failed', error: e, stackTrace: stackTrace);
        runApp(
          InitializationFailedScreen(
            error: e,
            stackTrace: stackTrace,
            onRetryInitialization: composeAndRun,
          ),
        );
      }
    }

    // Launch the application.
    await composeAndRun();
  }, logger.logZoneError);
}

void _configureBuildTracing(Logger logger) {
  if (kReleaseMode) return;
  if (_traceBuilds) {
    debugPrintRebuildDirtyWidgets = true;
    logger.info('READFLEX_TRACE_BUILDS enabled');
  }
  if (_profileBuilds) {
    debugProfileBuildsEnabled = true;
    logger.info('READFLEX_PROFILE_BUILDS enabled');
  }
  if (_profileUserBuilds) {
    debugProfileBuildsEnabledUserWidgets = true;
    logger.info('READFLEX_PROFILE_USER_BUILDS enabled');
  }
}
