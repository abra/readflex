import 'package:screen_brightness/screen_brightness.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'screen_control_service.dart';

/// Production [ScreenControlService] backed by `wakelock_plus`.
class WakelockScreenControlService implements ScreenControlService {
  const WakelockScreenControlService();

  @override
  Future<void> keepAwake() => WakelockPlus.enable();

  @override
  Future<void> allowSleep() => WakelockPlus.disable();

  @override
  Future<void> setApplicationBrightness(double brightness) {
    final clamped = brightness.clamp(0.0, 1.0).toDouble();
    return ScreenBrightness.instance.setApplicationScreenBrightness(clamped);
  }

  @override
  Future<void> resetApplicationBrightness() {
    return ScreenBrightness.instance.resetApplicationScreenBrightness();
  }
}
