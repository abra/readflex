/// Controls device screen-awake behavior.
abstract class ScreenControlService {
  /// Prevents the screen from sleeping.
  Future<void> keepAwake();

  /// Restores the platform's normal screen-sleep behavior.
  Future<void> allowSleep();
}

/// Stub implementation for tests and isolated previews.
class NoopScreenControlService implements ScreenControlService {
  const NoopScreenControlService();

  @override
  Future<void> keepAwake() async {}

  @override
  Future<void> allowSleep() async {}
}
