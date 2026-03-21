import 'package:flutter_test/flutter_test.dart';
import 'package:monitoring/monitoring.dart';

class _FakeErrorReporter implements ErrorReportingService {
  _FakeErrorReporter({this.isInitialized = true});

  @override
  bool isInitialized;

  final captured = <({Object throwable, StackTrace? stackTrace})>[];

  @override
  Future<void> initialize() async {}

  @override
  Future<void> close() async {}

  @override
  Future<void> captureException({
    required Object throwable,
    StackTrace? stackTrace,
  }) async => captured.add((throwable: throwable, stackTrace: stackTrace));
}

LogMessage _message(LogLevel level, {Object? error}) => LogMessage(
  message: 'msg',
  level: level,
  timestamp: DateTime.now(),
  error: error,
);

void main() {
  group('ErrorReporterLogObserver', () {
    test('forwards error level to reporter', () {
      final reporter = _FakeErrorReporter();
      final observer = ErrorReporterLogObserver(reporter);

      observer.onLog(_message(LogLevel.error, error: Exception('boom')));

      expect(reporter.captured, hasLength(1));
      expect(reporter.captured.first.throwable, isA<Exception>());
    });

    test('forwards fatal level to reporter', () {
      final reporter = _FakeErrorReporter();
      final observer = ErrorReporterLogObserver(reporter);

      observer.onLog(_message(LogLevel.fatal));

      expect(reporter.captured, hasLength(1));
    });

    test('uses message string when error is null', () {
      final reporter = _FakeErrorReporter();
      final observer = ErrorReporterLogObserver(reporter);

      observer.onLog(
        LogMessage(
          message: 'fallback message',
          level: LogLevel.error,
          timestamp: DateTime.now(),
        ),
      );

      expect(reporter.captured.first.throwable, 'fallback message');
    });

    test('does not forward trace, debug, info, warn', () {
      final reporter = _FakeErrorReporter();
      final observer = ErrorReporterLogObserver(reporter);

      for (final level in [
        LogLevel.trace,
        LogLevel.debug,
        LogLevel.info,
        LogLevel.warn,
      ]) {
        observer.onLog(_message(level));
      }

      expect(reporter.captured, isEmpty);
    });

    test('skips when reporter is not initialized', () {
      final reporter = _FakeErrorReporter(isInitialized: false);
      final observer = ErrorReporterLogObserver(reporter);

      observer.onLog(_message(LogLevel.error));

      expect(reporter.captured, isEmpty);
    });

    test('forwards stack trace when present', () {
      final reporter = _FakeErrorReporter();
      final observer = ErrorReporterLogObserver(reporter);
      final trace = StackTrace.current;

      observer.onLog(
        LogMessage(
          message: 'err',
          level: LogLevel.error,
          timestamp: DateTime.now(),
          stackTrace: trace,
        ),
      );

      expect(reporter.captured.first.stackTrace, trace);
    });
  });
}
