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
  static const _adaptiveBrightnessDivergenceThreshold = 0.08;

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
    return _readCurrentBrightnessOrNull();
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
      final brightnessInfo = _NativeBrightnessInfo.tryParse(info);
      final brightness = brightnessInfo?.effectiveBrightness;
      if (brightness != null) {
        _logNativeBrightness(info, brightnessInfo);
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

  static void _logNativeBrightness(
    Map<String, Object?>? info,
    _NativeBrightnessInfo? brightnessInfo,
  ) {
    if (info == null) return;
    debugPrint(
      '[reader-brightness-native] '
      'source=${info['source']} '
      'selected=${_debugBrightnessValue(info['brightness'])} '
      'effectiveSource=${brightnessInfo?.effectiveSource ?? 'none'} '
      'effective=${_debugBrightnessValue(brightnessInfo?.effectiveBrightness)} '
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

class _NativeBrightnessInfo {
  const _NativeBrightnessInfo({
    required this.source,
    required this.mode,
    required this.selected,
    required this.window,
    required this.display,
    required this.floatSetting,
    required this.intSetting,
  });

  static _NativeBrightnessInfo? tryParse(Map<String, Object?>? info) {
    if (info == null) return null;
    return _NativeBrightnessInfo(
      source: info['source'] as String?,
      mode: info['mode'] as String?,
      selected: _readBrightness(info['brightness']),
      window: _readBrightness(info['window']),
      display: _readBrightness(info['display']),
      floatSetting: _readBrightness(info['float']),
      intSetting: _readBrightness(info['int']),
    );
  }

  final String? source;
  final String? mode;
  final double? selected;
  final double? window;
  final double? display;
  final double? floatSetting;
  final double? intSetting;

  double? get effectiveBrightness {
    if (window != null) return window;
    if (_shouldUseAdaptiveBrightness) return adaptiveBrightness;
    return selected ?? intSetting ?? adaptiveBrightness;
  }

  String get effectiveSource {
    if (window != null) return 'window';
    if (_shouldUseAdaptiveBrightness) return _adaptiveSource;
    if (selected != null) return source ?? 'selected';
    if (intSetting != null) return 'intSetting';
    if (adaptiveBrightness != null) return _adaptiveSource;
    return 'none';
  }

  double? get adaptiveBrightness => display ?? floatSetting;

  String get _adaptiveSource =>
      display != null ? 'displayInfo' : 'floatSetting';

  bool get _shouldUseAdaptiveBrightness {
    final adaptive = adaptiveBrightness;
    final system = intSetting ?? selected;
    if (mode != 'automatic' || adaptive == null || system == null) return false;
    return (adaptive - system).abs() >=
        WakelockScreenControlService._adaptiveBrightnessDivergenceThreshold;
  }

  static double? _readBrightness(Object? value) {
    if (value is! num) return null;
    return WakelockScreenControlService._normalizeBrightness(value.toDouble());
  }
}

/// Result of the Android native brightness read. Separates "the platform
/// returned null/unavailable" from a real brightness value.
class _NativeBrightnessRead {
  const _NativeBrightnessRead.available(this.brightness) : available = true;

  const _NativeBrightnessRead.unavailable()
    : available = false,
      brightness = null;

  final bool available;
  final double? brightness;
}
