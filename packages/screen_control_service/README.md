# screen_control_service

Screen lifecycle controls for reader surfaces: keep-awake and temporary
application brightness.

Production uses `wakelock_plus` to keep the screen awake while bare reading
content is visible. The reader owns the lifetime: it enables keep-awake when no
chrome, drawer, or bottom sheet is visible, and releases it on controls,
route disposal, or app backgrounding.

On Android, production uses the Activity window brightness override, not a
write to the device's system setting. `System` mode removes that override.
Android reads platform brightness through the app's native channel, falling
back to the brightness plugin when that channel is unavailable.

On iOS, the plugin changes `UIScreen.brightness`; there is no Android-style
window override. The service captures the brightness before the first override
and restores that captured value on reset. It does not continuously track
system brightness changes made during the override. Reader lifecycle drivers
request reset on backgrounding/disposal and reapply the reader preference on
return. The same capture/restore fallback is used on other plugin platforms.

## Public API

| Symbol                         | Type           | Purpose                         |
|--------------------------------|----------------|---------------------------------|
| `ScreenControlService`         | abstract class | Keep-awake + app brightness contract |
| `WakelockScreenControlService` | concrete       | Production wrapper over wakelock + brightness |
| `NoopScreenControlService`     | concrete       | Test/preview no-op implementation |
