// Abstract interface for error reporting.
//
// Implement this class to integrate a real error reporting service
// (e.g. Firebase Crashlytics, Sentry).
// Use NoopErrorReporter during development or when reporting is disabled.

/// Contract for error reporting services.
abstract interface class ErrorReportingService {
  /// Whether the service has been initialized.
  bool get isInitialized;

  /// Initializes the error reporting service.
  ///
  /// Call once during app startup before reporting any errors.
  Future<void> initialize();

  /// Releases resources held by the service.
  Future<void> close();

  /// Reports an exception to the error reporting service.
  Future<void> captureException({
    required Object throwable,
    StackTrace? stackTrace,
  });
}

/// No-op implementation of [ErrorReportingService].
///
/// Does nothing — safe to use in development or when error reporting
/// is not configured. Replace with a real implementation for production.
final class NoopErrorReporter implements ErrorReportingService {
  const NoopErrorReporter();

  @override
  bool get isInitialized => false;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> close() async {}

  @override
  Future<void> captureException({
    required Object throwable,
    StackTrace? stackTrace,
  }) async {}
}
