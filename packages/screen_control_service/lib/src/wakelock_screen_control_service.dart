import 'dart:io';

import 'package:device_screen_brightness/device_screen_brightness.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'screen_control_service.dart';

typedef ReadDeviceBrightness = int Function({BrightnessMode mode});
typedef WriteDeviceBrightness =
    int Function(
      int value, {
      BrightnessMode mode,
    });

/// Production [ScreenControlService] backed by `wakelock_plus` and
/// `device_screen_brightness`.
class WakelockScreenControlService implements ScreenControlService {
  WakelockScreenControlService({
    ReadDeviceBrightness? readDeviceBrightness,
    WriteDeviceBrightness? writeDeviceBrightness,
    MethodChannel nativeScreenControlChannel = _defaultNativeChannel,
    BrightnessMode? brightnessMode,
    bool? useAndroidNativeAppBrightness,
    bool? useAndroidNativeReset,
  }) : _readDeviceBrightness =
           readDeviceBrightness ?? DeviceScreenBrightness.getBrightness,
       _writeDeviceBrightness =
           writeDeviceBrightness ?? DeviceScreenBrightness.setBrightness,
       _nativeScreenControlChannel = nativeScreenControlChannel,
       _brightnessMode =
           brightnessMode ??
           (Platform.isAndroid ? BrightnessMode.app : BrightnessMode.system),
       _useAndroidNativeAppBrightness =
           useAndroidNativeAppBrightness ?? Platform.isAndroid,
       _useAndroidNativeReset = useAndroidNativeReset ?? Platform.isAndroid;

  static const _defaultNativeChannel = MethodChannel(
    'io.github.abra.readflex/screen_control',
  );

  final ReadDeviceBrightness _readDeviceBrightness;
  final WriteDeviceBrightness _writeDeviceBrightness;
  final MethodChannel _nativeScreenControlChannel;
  final BrightnessMode _brightnessMode;
  final bool _useAndroidNativeAppBrightness;
  final bool _useAndroidNativeReset;
  double? _brightnessBeforeOverride;

  @override
  Future<void> keepAwake() => WakelockPlus.enable();

  @override
  Future<void> allowSleep() => WakelockPlus.disable();

  @override
  Future<void> setApplicationBrightness(double brightness) async {
    _brightnessBeforeOverride ??= await _readCurrentBrightnessOrNull();
    if (await _setAndroidApplicationBrightness(brightness)) return;
    final percent = _toPercent(brightness);
    _writeDeviceBrightness(percent, mode: _brightnessMode);
  }

  @override
  Future<double?> readApplicationBrightness() async {
    final brightness = await _readCurrentBrightnessOrNull();
    _brightnessBeforeOverride ??= brightness;
    return brightness;
  }

  @override
  Future<void> resetApplicationBrightness() async {
    if (_useAndroidNativeReset && await _resetAndroidApplicationBrightness()) {
      _brightnessBeforeOverride = null;
      return;
    }

    final baseline = _brightnessBeforeOverride;
    _brightnessBeforeOverride = null;
    if (baseline == null) return;
    _writeDeviceBrightness(_toPercent(baseline), mode: _brightnessMode);
  }

  Future<double?> _readCurrentBrightnessOrNull() async {
    final nativeRead = await _readAndroidApplicationBrightness();
    if (nativeRead.available) return nativeRead.brightness;

    try {
      final percent = _readDeviceBrightness(mode: _brightnessMode);
      return _fromPercent(percent);
    } on DeviceScreenBrightnessException {
      return null;
    }
  }

  Future<_NativeBrightnessRead> _readAndroidApplicationBrightness() async {
    if (!_useAndroidNativeAppBrightness) {
      return const _NativeBrightnessRead.unavailable();
    }
    try {
      final info = await _nativeScreenControlChannel
          .invokeMapMethod<String, Object?>('readApplicationBrightnessInfo');
      final brightness = _brightnessFromNativeInfo(info);
      if (brightness != null) {
        _logNativeBrightness(info);
        return _NativeBrightnessRead.available(brightness);
      }
    } on MissingPluginException {
      // Older native code only exposes the scalar method below.
    } on PlatformException {
      // Fall through to the scalar method before using the package backend.
    }

    try {
      final brightness = await _nativeScreenControlChannel.invokeMethod<double>(
        'readApplicationBrightness',
      );
      if (brightness == null) {
        return const _NativeBrightnessRead.unavailable();
      }
      return _NativeBrightnessRead.available(_normalizeBrightness(brightness));
    } on MissingPluginException {
      return const _NativeBrightnessRead.unavailable();
    } on PlatformException {
      return const _NativeBrightnessRead.unavailable();
    }
  }

  Future<bool> _setAndroidApplicationBrightness(double brightness) async {
    // The Activity window owns Android app brightness; use the app channel first.
    if (!_useAndroidNativeAppBrightness) return false;
    try {
      final applied = await _nativeScreenControlChannel.invokeMethod<double>(
        'setApplicationBrightness',
        {'brightness': _normalizeBrightness(brightness)},
      );
      return applied != null;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> _resetAndroidApplicationBrightness() async {
    try {
      await _nativeScreenControlChannel.invokeMethod<void>(
        'resetApplicationBrightness',
      );
      return true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static int _toPercent(double brightness) {
    return (_normalizeBrightness(brightness) * 100)
        .round()
        .clamp(0, 100)
        .toInt();
  }

  static double _normalizeBrightness(double brightness) {
    return brightness.clamp(0.0, 1.0).toDouble();
  }

  static double _fromPercent(int percent) {
    return percent.clamp(0, 100).toDouble() / 100.0;
  }

  static double? _brightnessFromNativeInfo(Map<String, Object?>? info) {
    final brightness = info?['brightness'];
    if (brightness is num) return _normalizeBrightness(brightness.toDouble());
    return null;
  }

  static void _logNativeBrightness(Map<String, Object?>? info) {
    if (info == null) return;
    debugPrint(
      '[reader-brightness-native] '
      'source=${info['source']} '
      'selected=${_debugBrightnessValue(info['brightness'])} '
      'window=${_debugBrightnessValue(info['window'])} '
      'display=${_debugBrightnessValue(info['display'])} '
      'float=${_debugBrightnessValue(info['float'])} '
      'int=${_debugBrightnessValue(info['int'])} '
      'raw=${info['intRaw']} '
      'range=${info['intMin']}..${info['intMax']} '
      'scale=${info['intScaleMin']}..${info['intScaleMax']} '
      'mode=${info['mode']}',
    );
  }

  static String _debugBrightnessValue(Object? value) {
    if (value is! num) return 'null';
    final brightness = _normalizeBrightness(value.toDouble());
    return '${(brightness * 100).round()}% (${brightness.toStringAsFixed(3)})';
  }
}

class _NativeBrightnessRead {
  const _NativeBrightnessRead.available(this.brightness) : available = true;

  const _NativeBrightnessRead.unavailable()
    : available = false,
      brightness = null;

  final bool available;
  final double? brightness;
}
