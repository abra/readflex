/// Controls device screen-awake behavior.
abstract class ScreenControlService {
  /// Prevents the screen from sleeping.
  Future<void> keepAwake();

  /// Restores the platform's normal screen-sleep behavior.
  Future<void> allowSleep();

  /// Sets temporary application brightness for the current app session.
  Future<void> setApplicationBrightness(double brightness);

  /// Resets application brightness back to the platform/system value.
  Future<void> resetApplicationBrightness();
}

/// Stub implementation for tests and isolated previews.
class NoopScreenControlService implements ScreenControlService {
  const NoopScreenControlService();

  @override
  Future<void> keepAwake() async {}

  @override
  Future<void> allowSleep() async {}

  @override
  Future<void> setApplicationBrightness(double brightness) async {}

  @override
  Future<void> resetApplicationBrightness() async {}
}
