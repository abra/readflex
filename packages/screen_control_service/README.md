# screen_control_service

Screen lifecycle controls for reader surfaces.

Production uses `wakelock_plus` to keep the screen awake while bare reading
content is visible. The reader owns the lifetime: it enables keep-awake when no
chrome, drawer, or bottom sheet is visible, and releases it on controls,
route disposal, or app backgrounding.

## Public API

| Symbol                         | Type           | Purpose                         |
|--------------------------------|----------------|---------------------------------|
| `ScreenControlService`         | abstract class | Keep-awake contract             |
| `WakelockScreenControlService` | concrete       | Production wakelock wrapper     |
| `NoopScreenControlService`     | concrete       | Test/preview no-op implementation |
