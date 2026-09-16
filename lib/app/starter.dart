// Application bootstrap: error zone, Flutter binding initialization, runApp.
//
// Sets up runZonedGuarded to catch all unhandled async errors.
// Configures FlutterError.onError and platformDispatcher.onError so that
// errors at every level are routed to the logger.
// On initialization failure — shows a recovery screen instead of crashing.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:monitoring/monitoring.dart';
import 'package:readflex/app/app_bootstrap.dart';
import 'package:readflex/app/app_scopes.dart';
import 'package:readflex/app/bloc/app_bloc_observer.dart';
import 'package:readflex/app/bloc/bloc_transformer.dart';
import 'package:readflex/app/composition.dart';
import 'package:readflex/app/config/application_config.dart';
import 'package:readflex/app/frame_timing_tracing.dart';
import 'package:readflex/app/screens/initialization_failed_screen.dart';

// Prints dirty widget rebuilds to the console during rebuild audits.
const _traceBuilds = bool.fromEnvironment('READFLEX_TRACE_BUILDS');

// Emits Flutter build profiling events for inspection in DevTools Timeline.
const _profileBuilds = bool.fromEnvironment('READFLEX_PROFILE_BUILDS');

// Limits build profiling noise to user widgets when framework widgets are not useful.
const _profileUserBuilds = bool.fromEnvironment(
  'READFLEX_PROFILE_USER_BUILDS',
);

/// Initializes dependencies and runs app.
Future<void> starter() async {
  const config = ApplicationConfig();

  final logger = createAppLogger(
    observers: [
      if (!kReleaseMode) const PrintingLogObserver(logLevel: LogLevel.trace),
    ],
  );

  await runZonedGuarded(() async {
    // Ensure Flutter is initialized.
    WidgetsFlutterBinding.ensureInitialized();
    _configureBuildTracing(logger);
    configureFrameTimingTracing(logger);

    // Configure global error interception.
    FlutterError.onError = logger.logFlutterError;
    WidgetsBinding.instance.platformDispatcher.onError =
        logger.logPlatformDispatcherError;

    // Setup bloc observer and transformer.
    Bloc.observer = AppBlocObserver(logger);
    Bloc.transformer = SequentialBlocTransformer<Object?>().transform;

    final bootstrap = AppBootstrap(config: config, logger: logger);
    Future<void> composeAndRun() => bootstrap.run(
      onReady: (dependencies) => runApp(AppScopes(dependencies: dependencies)),
      onFailure: (error, stackTrace) => runApp(
        InitializationFailedScreen(
          error: error,
          stackTrace: stackTrace,
          onRetryInitialization: composeAndRun,
        ),
      ),
    );

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
