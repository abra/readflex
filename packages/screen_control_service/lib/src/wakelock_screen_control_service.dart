import 'package:wakelock_plus/wakelock_plus.dart';

import 'screen_control_service.dart';

/// Production [ScreenControlService] backed by `wakelock_plus`.
class WakelockScreenControlService implements ScreenControlService {
  const WakelockScreenControlService();

  @override
  Future<void> keepAwake() => WakelockPlus.enable();

  @override
  Future<void> allowSleep() => WakelockPlus.disable();
}
