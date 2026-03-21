// LogObserver that prints formatted log messages to the console.
//
// Attach to Logger in debug/profile builds only.
// Each line includes timestamp, short level name, message and optional error.

import 'package:flutter/foundation.dart';
import 'package:monitoring/src/logger.dart';

/// Prints log messages to the console via [debugPrint].
///
/// Only messages at or above [logLevel] are printed.
final class PrintingLogObserver with LogObserver {
  const PrintingLogObserver({required this.logLevel});

  final LogLevel logLevel;

  @override
  void onLog(LogMessage logMessage) {
    if (logMessage.level.index < logLevel.index) return;

    final dt = logMessage.timestamp;
    final timestamp =
        '${_pad(dt.month)}-${_pad(dt.day)} '
        '${_pad(dt.hour)}:${_pad(dt.minute)}:${_pad(dt.second)}';

    final buffer = StringBuffer()
      ..write(timestamp)
      ..write(' [${logMessage.level.toShortName()}]')
      ..write(' ${logMessage.message}');

    if (logMessage.error case final error?) {
      buffer.write('\n$error');
    }

    if (logMessage.stackTrace case final stack?) {
      buffer.write('\n$stack');
    }

    debugPrint(buffer.toString());
  }

  String _pad(int value) => value.toString().padLeft(2, '0');
}
