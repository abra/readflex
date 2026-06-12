import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:monitoring/monitoring.dart';

const _traceFrameTimings = bool.fromEnvironment(
  'READFLEX_TRACE_FRAME_TIMINGS',
);
const _frameTimingBudgetMs = int.fromEnvironment(
  'READFLEX_TRACE_FRAME_TIMING_BUDGET_MS',
  defaultValue: 16,
);
const _defaultFrameTimingBudgetMs = 16;

void configureFrameTimingTracing(Logger logger) {
  if (kReleaseMode || !_traceFrameTimings) return;

  final budget = frameTimingBudgetFromMilliseconds(_frameTimingBudgetMs);
  SchedulerBinding.instance.addTimingsCallback((timings) {
    for (final timing in timings) {
      final message = frameTimingTraceMessage(timing, budget: budget);
      if (message != null) {
        logger.info(message);
      }
    }
  });
  logger.info(
    'READFLEX_TRACE_FRAME_TIMINGS enabled '
    'budget=${formatFrameTimingDuration(budget)}',
  );
}

@visibleForTesting
Duration frameTimingBudgetFromMilliseconds(int budgetMs) {
  return Duration(
    milliseconds: budgetMs > 0 ? budgetMs : _defaultFrameTimingBudgetMs,
  );
}

@visibleForTesting
String? frameTimingTraceMessage(
  FrameTiming timing, {
  required Duration budget,
}) {
  final buildOverBudget = timing.buildDuration > budget;
  final rasterOverBudget = timing.rasterDuration > budget;
  final totalOverBudget = timing.totalSpan > budget;
  if (!buildOverBudget && !rasterOverBudget && !totalOverBudget) {
    return null;
  }

  final overBudget = [
    if (buildOverBudget) 'build',
    if (rasterOverBudget) 'raster',
    if (totalOverBudget) 'total',
  ].join(',');

  return '[frame-timing] slow '
      'frame=${timing.frameNumber} '
      'over=$overBudget '
      'budget=${formatFrameTimingDuration(budget)} '
      'build=${formatFrameTimingDuration(timing.buildDuration)} '
      'raster=${formatFrameTimingDuration(timing.rasterDuration)} '
      'total=${formatFrameTimingDuration(timing.totalSpan)} '
      'vsync=${formatFrameTimingDuration(timing.vsyncOverhead)} '
      'layerCache=${timing.layerCacheCount}/'
      '${formatFrameTimingBytes(timing.layerCacheBytes)} '
      'pictureCache=${timing.pictureCacheCount}/'
      '${formatFrameTimingBytes(timing.pictureCacheBytes)}';
}

@visibleForTesting
String formatFrameTimingDuration(Duration duration) {
  final micros = duration.inMicroseconds;
  final sign = micros < 0 ? '-' : '';
  final absMicros = micros.abs();
  final wholeMs = absMicros ~/ Duration.microsecondsPerMillisecond;
  final tenthMs =
      (absMicros % Duration.microsecondsPerMillisecond) ~/
      (Duration.microsecondsPerMillisecond ~/ 10);
  return '$sign$wholeMs.${tenthMs}ms';
}

@visibleForTesting
String formatFrameTimingBytes(int bytes) {
  if (bytes < 1024) return '${bytes}B';
  final kib = bytes / 1024;
  if (kib < 1024) return '${kib.toStringAsFixed(1)}KiB';
  final mib = kib / 1024;
  return '${mib.toStringAsFixed(1)}MiB';
}
