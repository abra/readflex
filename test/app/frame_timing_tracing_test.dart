import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:readflex/app/frame_timing_tracing.dart';

void main() {
  group('frameTimingTraceMessage', () {
    test('returns null when frame stays within budget', () {
      final timing = _frameTiming(
        buildMicros: 4000,
        rasterMicros: 5000,
        frameNumber: 1,
      );

      expect(
        frameTimingTraceMessage(
          timing,
          budget: const Duration(milliseconds: 16),
        ),
        isNull,
      );
    });

    test('reports build, raster, and total budget misses', () {
      final timing = _frameTiming(
        buildMicros: 17000,
        rasterMicros: 19000,
        layerCacheBytes: 2048,
        pictureCacheBytes: 3 * 1024 * 1024,
        frameNumber: 42,
      );

      final message = frameTimingTraceMessage(
        timing,
        budget: const Duration(milliseconds: 16),
      );

      expect(message, contains('[frame-timing] slow'));
      expect(message, contains('frame=42'));
      expect(message, contains('over=build,raster,total'));
      expect(message, contains('budget=16.0ms'));
      expect(message, contains('build=17.0ms'));
      expect(message, contains('raster=19.0ms'));
      expect(message, contains('layerCache=2/2.0KiB'));
      expect(message, contains('pictureCache=3/3.0MiB'));
    });

    test('falls back to default budget for invalid values', () {
      expect(
        frameTimingBudgetFromMilliseconds(-1),
        const Duration(milliseconds: 16),
      );
      expect(
        frameTimingBudgetFromMilliseconds(33),
        const Duration(milliseconds: 33),
      );
    });
  });
}

FrameTiming _frameTiming({
  required int buildMicros,
  required int rasterMicros,
  required int frameNumber,
  int layerCacheBytes = 0,
  int pictureCacheBytes = 0,
}) {
  const vsyncStart = 0;
  const buildStart = 1000;
  final buildFinish = buildStart + buildMicros;
  final rasterStart = buildFinish;
  final rasterFinish = rasterStart + rasterMicros;
  return FrameTiming(
    vsyncStart: vsyncStart,
    buildStart: buildStart,
    buildFinish: buildFinish,
    rasterStart: rasterStart,
    rasterFinish: rasterFinish,
    rasterFinishWallTime: rasterFinish,
    layerCacheCount: layerCacheBytes == 0 ? 0 : 2,
    layerCacheBytes: layerCacheBytes,
    pictureCacheCount: pictureCacheBytes == 0 ? 0 : 3,
    pictureCacheBytes: pictureCacheBytes,
    frameNumber: frameNumber,
  );
}
