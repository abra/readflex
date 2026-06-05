# screen_control_service

Screen lifecycle controls for reader surfaces: keep-awake and temporary
application brightness.

Production uses `wakelock_plus` to keep the screen awake while bare reading
content is visible. The reader owns the lifetime: it enables keep-awake when no
chrome, drawer, or bottom sheet is visible, and releases it on controls,
route disposal, or app backgrounding.

Production uses the app window brightness override for temporary reader
brightness. This does not write the device's system brightness; `System` mode
resets the app window back to the platform default, while custom reader
brightness is applied only while the reader is active. Android reads the best
available platform value for the first custom step and diagnostics before
falling back to `Settings.System`.

## Public API

| Symbol                         | Type           | Purpose                         |
|--------------------------------|----------------|---------------------------------|
| `ScreenControlService`         | abstract class | Keep-awake + app brightness contract |
| `WakelockScreenControlService` | concrete       | Production wrapper over wakelock + brightness |
| `NoopScreenControlService`     | concrete       | Test/preview no-op implementation |
