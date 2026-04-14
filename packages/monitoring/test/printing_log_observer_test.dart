import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monitoring/monitoring.dart';

void main() {
  group('PrintingLogObserver', () {
    late List<String> printedMessages;

    setUp(() {
      printedMessages = [];
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) printedMessages.add(message);
      };
    });

    tearDown(() {
      debugPrint = debugPrintThrottled;
    });

    test('prints messages at or above threshold', () {
      const observer = PrintingLogObserver(logLevel: LogLevel.info);

      observer.onLog(
        LogMessage(
          message: 'test info',
          level: LogLevel.info,
          timestamp: DateTime(2026, 4, 1, 12, 30, 45),
        ),
      );

      expect(printedMessages, hasLength(1));
      expect(printedMessages.first, contains('test info'));
      expect(printedMessages.first, contains('[INF]'));
      expect(printedMessages.first, contains('04-01 12:30:45'));
    });

    test('skips messages below threshold', () {
      const observer = PrintingLogObserver(logLevel: LogLevel.warn);

      observer.onLog(
        LogMessage(
          message: 'debug msg',
          level: LogLevel.debug,
          timestamp: DateTime(2026, 4, 1),
        ),
      );

      expect(printedMessages, isEmpty);
    });

    test('includes error when present', () {
      const observer = PrintingLogObserver(logLevel: LogLevel.error);

      observer.onLog(
        LogMessage(
          message: 'oops',
          level: LogLevel.error,
          timestamp: DateTime(2026, 4, 1),
          error: Exception('boom'),
        ),
      );

      expect(printedMessages, hasLength(1));
      expect(printedMessages.first, contains('boom'));
    });

    test('includes stack trace when present', () {
      const observer = PrintingLogObserver(logLevel: LogLevel.error);
      final stack = StackTrace.current;

      observer.onLog(
        LogMessage(
          message: 'oops',
          level: LogLevel.error,
          timestamp: DateTime(2026, 4, 1),
          stackTrace: stack,
        ),
      );

      expect(printedMessages, hasLength(1));
      expect(printedMessages.first, contains(stack.toString().split('\n')[0]));
    });
  });

  group('LogLevel.toShortName()', () {
    test('returns correct short names', () {
      expect(LogLevel.trace.toShortName(), 'TRC');
      expect(LogLevel.debug.toShortName(), 'DBG');
      expect(LogLevel.info.toShortName(), 'INF');
      expect(LogLevel.warn.toShortName(), 'WRN');
      expect(LogLevel.error.toShortName(), 'ERR');
      expect(LogLevel.fatal.toShortName(), 'FTL');
    });
  });
}
