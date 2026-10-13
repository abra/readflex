# Readflex patch

This directory vendors `device_screen_brightness` 0.3.1 from pub.dev
(<https://github.com/arcas0803/device_screen_brightness>, MIT). The upstream
license and sources are retained. `packages/screen_control_service` depends on
it by path; it is not published or overridden through `dependency_overrides`.

## Android brightness scale

Readflex sets the reader's brightness through the Activity window override
(`BrightnessMode.app`), so the slider must map linearly onto
`WindowManager.LayoutParams.screenBrightness`. Upstream passed window
brightness through the Android 9+ perceptual (HLG) curve as well, so the
slider value and the window override differed.

`DeviceScreenBrightnessHelper` now reads and writes window brightness as a
direct 0..1 value. The system setting (`Settings.System.SCREEN_BRIGHTNESS`,
`BrightnessMode.system`) keeps upstream's behaviour: the perceptual curve on
Android 9+, as the system Settings slider shows it, and the legacy 0..255
scale for small values on devices that report a larger range; that code was
only restructured. iOS, macOS, Linux and Windows code is unchanged.

## Verification

`make verify` runs the package's Dart tests (`test/`) and analysis. They cover
the Dart API and error mapping, not the Java helper. After changing the Android
code, check on a device that the reader brightness slider follows the finger
evenly from 0 to 100 and that returning to the reader keeps the chosen value.
Recheck the patch when updating this vendored package.
