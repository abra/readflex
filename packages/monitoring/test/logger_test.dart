import 'package:flutter_test/flutter_test.dart';
import 'package:monitoring/monitoring.dart';

class _RecordingObserver with LogObserver {
  final messages = <LogMessage>[];

  @override
  void onLog(LogMessage logMessage) => messages.add(logMessage);
}

void main() {
  group('Logger', () {
    test('dispatches log to observer', () {
      final observer = _RecordingObserver();
      final logger = Logger(observers: [observer]);

      logger.info('hello');

      expect(observer.messages, hasLength(1));
      expect(observer.messages.first.message, 'hello');
      expect(observer.messages.first.level, LogLevel.info);
    });

    test('dispatches log to multiple observers', () {
      final observer1 = _RecordingObserver();
      final observer2 = _RecordingObserver();
      final logger = Logger(observers: [observer1, observer2]);

      logger.warn('broadcast');

      expect(observer1.messages, hasLength(1));
      expect(observer2.messages, hasLength(1));
    });

    test('each log level sets correct level on message', () {
      final observer = _RecordingObserver();
      final logger = Logger(observers: [observer]);

      logger.trace('t');
      logger.debug('d');
      logger.info('i');
      logger.warn('w');
      logger.error('e');
      logger.fatal('f');

      expect(observer.messages.map((m) => m.level), [
        LogLevel.trace,
        LogLevel.debug,
        LogLevel.info,
        LogLevel.warn,
        LogLevel.error,
        LogLevel.fatal,
      ]);
    });

    test('addObserver registers observer after construction', () {
      final observer = _RecordingObserver();
      final logger = Logger();

      logger.addObserver(observer);
      logger.info('added');

      expect(observer.messages, hasLength(1));
    });

    test('removeObserver stops receiving logs', () {
      final observer = _RecordingObserver();
      final logger = Logger(observers: [observer]);

      logger.info('before');
      logger.removeObserver(observer);
      logger.info('after');

      expect(observer.messages, hasLength(1));
      expect(observer.messages.first.message, 'before');
    });

    test('does not dispatch after destroy()', () async {
      final observer = _RecordingObserver();
      final logger = Logger(observers: [observer]);

      await logger.destroy();
      logger.info('after destroy');

      expect(observer.messages, isEmpty);
    });

    test('destroy() is idempotent', () async {
      final logger = Logger();

      await logger.destroy();
      await logger.destroy(); // should not throw
    });

    test('logZoneError logs at error level', () {
      final observer = _RecordingObserver();
      final logger = Logger(observers: [observer]);

      logger.logZoneError(Exception('zone'), StackTrace.empty);

      expect(observer.messages.first.level, LogLevel.error);
      expect(observer.messages.first.error, isA<Exception>());
    });
  });
}
