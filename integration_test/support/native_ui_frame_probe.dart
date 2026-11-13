import 'dart:developer' show Timeline;
import 'dart:ui' show FramePhase, FrameTiming;

import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

/// Measures warmed native frames without requesting extra benchmark frames.
final class NativeUiFrameProbe {
  const NativeUiFrameProbe(this.tester);

  final WidgetTester tester;

  Future<Map<String, Object?>> measure({
    required int cycles,
    required Future<void> Function() action,
  }) async {
    // The engine delivers timing batches independently of framework frames.
    await tester.pump(const Duration(milliseconds: 1100));
    final timings = <FrameTiming>[];
    final refreshRates = <double>{tester.view.display.refreshRate};
    void record(List<FrameTiming> batch) {
      timings.addAll(batch);
      refreshRates.add(tester.view.display.refreshRate);
    }

    final refreshRate = tester.view.display.refreshRate;
    final budgetUs = refreshRate > 0 ? 1000000 / refreshRate : null;
    final binding = SchedulerBinding.instance;
    binding.addTimingsCallback(record);
    final startedUs = Timeline.now;
    late int endedUs;
    try {
      await action();
      endedUs = Timeline.now;
      await tester.pump(const Duration(milliseconds: 1100));
    } finally {
      binding.removeTimingsCallback(record);
    }
    refreshRates.add(tester.view.display.refreshRate);
    final frames = timings.where((timing) {
      final started = timing.timestampInMicroseconds(FramePhase.buildStart);
      return started >= startedUs && started < endedUs;
    }).toList();
    expect(frames, isNotEmpty, reason: 'The native engine must report frames');
    return {
      'cycles': cycles,
      'elapsedUs': endedUs - startedUs,
      'startedAtMonotonicUs': startedUs,
      'endedAtMonotonicUs': endedUs,
      'frameCount': frames.length,
      'samplePolicy': 'buildStart within the warmed workload window',
      'refreshRateHz': refreshRate,
      'observedRefreshRatesHz': refreshRates.toList()..sort(),
      'frameBudgetUs': budgetUs,
      'budgetPolicy':
          'Nominal Flutter display refresh rate; variable refresh '
          'and OS compositor presentation are not inferred',
      'build': _summarize(
        frames.map((frame) => frame.buildDuration.inMicroseconds),
        budgetUs,
      ),
      'raster': _summarize(
        frames.map((frame) => frame.rasterDuration.inMicroseconds),
        budgetUs,
      ),
      'totalSpan': _summarize(
        frames.map((frame) => frame.totalSpan.inMicroseconds),
        budgetUs,
      ),
      'pipelineOverBudgetFrames': budgetUs == null
          ? null
          : frames.where((frame) {
              return frame.buildDuration.inMicroseconds > budgetUs ||
                  frame.rasterDuration.inMicroseconds > budgetUs;
            }).length,
      'frames': [
        for (final frame in frames)
          {
            'vsyncStartUs': frame.timestampInMicroseconds(
              FramePhase.vsyncStart,
            ),
            'buildStartUs': frame.timestampInMicroseconds(
              FramePhase.buildStart,
            ),
            'buildUs': frame.buildDuration.inMicroseconds,
            'rasterUs': frame.rasterDuration.inMicroseconds,
            'totalSpanUs': frame.totalSpan.inMicroseconds,
          },
      ],
    };
  }
}

Map<String, Object?> _summarize(Iterable<int> durations, double? budgetUs) {
  final sorted = durations.toList()..sort();
  return {
    'p50Us': sorted[(sorted.length * .5).ceil() - 1],
    'p95Us': sorted[(sorted.length * .95).ceil() - 1],
    'maxUs': sorted.last,
    'overBudget': budgetUs == null
        ? null
        : sorted.where((duration) => duration > budgetUs).length,
  };
}
