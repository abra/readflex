import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_device_font_scale.dart';

void main() {
  group('readerDeviceFontScale', () {
    test('does not change iOS reader size', () {
      expect(
        readerDeviceFontScale(
          platform: TargetPlatform.iOS,
          viewportSize: const Size(430, 932),
        ),
        1.0,
      );
    });

    test('boosts Android phone reader size', () {
      expect(
        readerDeviceFontScale(
          platform: TargetPlatform.android,
          viewportSize: const Size(393, 873),
        ),
        closeTo(1.109, 0.001),
      );
    });

    test('uses a smaller boost on Android tablet widths', () {
      expect(
        readerDeviceFontScale(
          platform: TargetPlatform.android,
          viewportSize: const Size(600, 960),
        ),
        1.04,
      );
    });

    test('falls back to phone scale for invalid viewport', () {
      expect(
        readerDeviceFontScale(
          platform: TargetPlatform.android,
          viewportSize: Size.zero,
        ),
        1.12,
      );
    });
  });
}
