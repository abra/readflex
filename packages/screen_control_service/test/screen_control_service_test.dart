import 'package:flutter_test/flutter_test.dart';
import 'package:screen_control_service/screen_control_service.dart';

void main() {
  group('NoopScreenControlService', () {
    test('keepAwake completes without error', () async {
      const service = NoopScreenControlService();

      await expectLater(service.keepAwake(), completes);
    });

    test('allowSleep completes without error', () async {
      const service = NoopScreenControlService();

      await expectLater(service.allowSleep(), completes);
    });

    test('setApplicationBrightness completes without error', () async {
      const service = NoopScreenControlService();

      await expectLater(service.setApplicationBrightness(0.4), completes);
    });

    test('resetApplicationBrightness completes without error', () async {
      const service = NoopScreenControlService();

      await expectLater(service.resetApplicationBrightness(), completes);
    });
  });
}
