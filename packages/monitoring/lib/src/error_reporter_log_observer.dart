// LogObserver that forwards error-level logs to ErrorReportingService.
//
// Bridges the logger and error reporter: any log at error level or above
// is automatically captured, so callers only need to log — not report manually.

import 'package:monitoring/src/error_reporting_service.dart';
import 'package:monitoring/src/logger.dart';

/// Forwards [LogLevel.error] and above to [ErrorReportingService].
final class ErrorReporterLogObserver with LogObserver {
  const ErrorReporterLogObserver(this._errorReporter);

  final ErrorReportingService _errorReporter;

  @override
  void onLog(LogMessage logMessage) {
    if (!_errorReporter.isInitialized) return;

    if (logMessage.level.index >= LogLevel.error.index) {
      _errorReporter.captureException(
        throwable: logMessage.error ?? logMessage.message,
        stackTrace: logMessage.stackTrace,
      );
    }
  }
}
