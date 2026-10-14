import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_device_font_scale.dart';

void main() {
  double scale(TargetPlatform platform, Size window) =>
      readerDeviceFontScale(platform: platform, viewportSize: window);

  group('readerDeviceFontScale on iOS', () {
    double ios(Size window) => scale(TargetPlatform.iOS, window);

    test('does not change phone reader size', () {
      for (final window in const [
        Size(320, 568),
        Size(390, 844),
        Size(402, 874),
        Size(440, 956),
      ]) {
        expect(ios(window), 1.0, reason: '$window');
      }
    });

    test('keeps phones unchanged in landscape', () {
      expect(ios(const Size(844, 390)), 1.0);
      expect(ios(const Size(956, 440)), 1.0);
    });

    test('makes book text 12.5% larger in tablet-sized windows', () {
      for (final window in const [
        Size(744, 1133), // iPad mini
        Size(820, 1180), // iPad Air 11"
        Size(1032, 1376), // iPad Pro 13"
      ]) {
        expect(ios(window), 1.125, reason: '$window');
      }
    });

    test('keeps the size when a tablet rotates', () {
      expect(ios(const Size(1376, 1032)), ios(const Size(1032, 1376)));
      expect(ios(const Size(1133, 744)), ios(const Size(744, 1133)));
    });

    test('reads a narrow multitasking window like a phone', () {
      // Slide Over and a one-third Split View on iPad.
      expect(ios(const Size(375, 1032)), 1.0);
      expect(ios(const Size(1032, 375)), 1.0);
      // A half Split View on iPad Pro 13" is still tablet-sized.
      expect(ios(const Size(678, 1032)), 1.125);
    });

    test('starts the tablet size at a 600 shortest side', () {
      expect(ios(const Size(600, 900)), 1.125);
      expect(ios(const Size(599.9, 900)), 1.0);
      expect(ios(const Size(900, 600)), 1.125);
    });

    test('treats an unknown window as a phone', () {
      expect(ios(Size.zero), 1.0);
    });
  });

  group('readerDeviceFontScale on Android', () {
    double android(Size window) => scale(TargetPlatform.android, window);

    test('boosts phone reader size', () {
      expect(android(const Size(360, 780)), 1.12);
      expect(android(const Size(393, 873)), closeTo(1.109, 0.001));
    });

    test('blends the phone boost between phone and tablet widths', () {
      expect(android(const Size(480, 900)), closeTo(1.08, 1e-9));
      expect(android(const Size(599, 900)), closeTo(1.0403, 1e-4));
    });

    test('combines the tablet boost with the tablet text size', () {
      expect(android(const Size(600, 960)), closeTo(1.04 * 1.125, 1e-9));
      expect(android(const Size(1280, 800)), closeTo(1.17, 1e-9));
    });

    test('keeps the size when a tablet rotates', () {
      expect(android(const Size(800, 1280)), android(const Size(1280, 800)));
    });

    test('falls back to phone scale for invalid viewport', () {
      expect(android(Size.zero), 1.12);
    });
  });

  test('other platforms get only the tablet text size', () {
    for (final platform in const [
      TargetPlatform.macOS,
      TargetPlatform.fuchsia,
      TargetPlatform.linux,
      TargetPlatform.windows,
    ]) {
      expect(scale(platform, const Size(390, 844)), 1.0, reason: '$platform');
      expect(
        scale(platform, const Size(1280, 800)),
        1.125,
        reason: '$platform',
      );
    }
  });
}
