import 'package:flutter/foundation.dart';

// Reader-only trace switch for correlating screen rebuilds with reader events.
const _traceReaderBuilds = bool.fromEnvironment(
  'READFLEX_TRACE_READER_BUILDS',
);

void debugTraceReader(String message) {
  if (!_traceReaderBuilds || kReleaseMode) return;
  debugPrint('[reader-trace] $message');
}

void debugTraceReaderHighlight(String message) {
  if (!kDebugMode) return;
  debugPrint('[reader-highlight] $message');
}

String readerHighlightTraceText(String text) {
  final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  return normalized.length <= 48
      ? normalized
      : '${normalized.substring(0, 48)}...';
}

String readerHighlightTraceAnchor(String? cfiRange) {
  if (cfiRange == null || cfiRange.isEmpty) return 'none';
  return '${cfiRange.length}:'
      '${cfiRange.hashCode.toUnsigned(32).toRadixString(16)}';
}
