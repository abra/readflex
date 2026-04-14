import 'package:flutter_test/flutter_test.dart';
import 'package:monitoring/monitoring.dart';

final class _TestEvent extends AnalyticsEvent {
  @override
  String get name => 'test_event';

  @override
  Map<String, Object?> get parameters => {'key': 'value'};
}

void main() {
  group('NoopAnalyticsReporter', () {
    const reporter = NoopAnalyticsReporter();

    test('isInitialized is false', () {
      expect(reporter.isInitialized, isFalse);
    });

    test('initialize completes without error', () async {
      await reporter.initialize();
    });

    test('close completes without error', () async {
      await reporter.close();
    });

    test('logEvent completes without error', () async {
      await reporter.logEvent(_TestEvent());
    });

    test('setUserId completes without error', () async {
      await reporter.setUserId('user-1');
      await reporter.setUserId(null);
    });
  });

  group('NoopErrorReporter', () {
    const reporter = NoopErrorReporter();

    test('isInitialized is false', () {
      expect(reporter.isInitialized, isFalse);
    });

    test('initialize completes without error', () async {
      await reporter.initialize();
    });

    test('close completes without error', () async {
      await reporter.close();
    });

    test('captureException completes without error', () async {
      await reporter.captureException(
        throwable: Exception('test'),
        stackTrace: StackTrace.current,
      );
    });
  });
}
