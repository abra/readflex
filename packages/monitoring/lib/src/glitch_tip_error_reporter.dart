import 'package:flutter/foundation.dart';
import 'package:monitoring/src/error_reporting_service.dart';
import 'package:sentry/sentry.dart';

/// Configuration used to initialize GlitchTip through the Sentry Dart SDK.
@immutable
class GlitchTipReporterConfig {
  const GlitchTipReporterConfig({
    required this.dsn,
    required this.environment,
    this.release,
    this.tracesSampleRate = 0,
  });

  final String dsn;
  final String environment;
  final String? release;
  final double tracesSampleRate;
}

/// Small adapter boundary around the Sentry SDK for tests and future swaps.
abstract interface class GlitchTipReporterClient {
  bool get isEnabled;

  Future<void> initialize(GlitchTipReporterConfig config);

  Future<void> captureException({
    required Object throwable,
    StackTrace? stackTrace,
  });

  Future<void> close();
}

/// Sentry-compatible Dart client that sends events to a GlitchTip DSN.
final class SentryGlitchTipReporterClient implements GlitchTipReporterClient {
  const SentryGlitchTipReporterClient();

  @override
  bool get isEnabled => Sentry.isEnabled;

  @override
  Future<void> initialize(GlitchTipReporterConfig config) {
    return Sentry.init((options) {
      options
        ..dsn = config.dsn
        ..environment = config.environment
        ..sendDefaultPii = false
        ..tracesSampleRate = _clampSampleRate(config.tracesSampleRate);

      final release = config.release?.trim();
      if (release != null && release.isNotEmpty) {
        options.release = release;
      }
    });
  }

  @override
  Future<void> captureException({
    required Object throwable,
    StackTrace? stackTrace,
  }) {
    return Sentry.captureException(throwable, stackTrace: stackTrace);
  }

  @override
  Future<void> close() => Sentry.close();
}

/// Production error reporter for self-hosted GlitchTip.
final class GlitchTipErrorReporter implements ErrorReportingService {
  GlitchTipErrorReporter({
    required String dsn,
    required String environment,
    String? release,
    double tracesSampleRate = 0,
    GlitchTipReporterClient client = const SentryGlitchTipReporterClient(),
  }) : _config = GlitchTipReporterConfig(
         dsn: dsn.trim(),
         environment: environment.trim(),
         release: release,
         tracesSampleRate: _clampSampleRate(tracesSampleRate),
       ),
       _client = client;

  final GlitchTipReporterConfig _config;
  final GlitchTipReporterClient _client;

  var _initialized = false;

  @override
  bool get isInitialized => _initialized;

  @override
  Future<void> initialize() async {
    if (_initialized || _config.dsn.isEmpty) return;

    try {
      await _client.initialize(_config);
      _initialized = _client.isEnabled;
    } on Object {
      // Error reporting must never prevent the app from starting.
      _initialized = false;
    }
  }

  @override
  Future<void> captureException({
    required Object throwable,
    StackTrace? stackTrace,
  }) {
    if (!_initialized) return Future<void>.value();

    return _client.captureException(
      throwable: throwable,
      stackTrace: stackTrace,
    );
  }

  @override
  Future<void> close() async {
    if (!_initialized) return;

    await _client.close();
    _initialized = false;
  }
}

double _clampSampleRate(double value) {
  if (value.isNaN) return 0;
  if (value < 0) return 0;
  if (value > 1) return 1;
  return value;
}
