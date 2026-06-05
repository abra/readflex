import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:screen_control_service/screen_control_service.dart';

class ReaderBrightnessState extends Equatable {
  const ReaderBrightnessState({
    required this.brightnessOverride,
    required this.lastCustomBrightness,
    this.systemBrightness,
  });

  final double? brightnessOverride;
  final double lastCustomBrightness;
  final double? systemBrightness;

  bool get usesSystemBrightness => brightnessOverride == null;

  double get sliderValue =>
      brightnessOverride ?? systemBrightness ?? lastCustomBrightness;

  double get controlValue => sliderValue;

  int get percent => (sliderValue * 100).round();

  @override
  List<Object?> get props => [
    brightnessOverride,
    lastCustomBrightness,
    systemBrightness,
  ];
}

class ReaderBrightnessCubit extends Cubit<ReaderBrightnessState> {
  ReaderBrightnessCubit({
    required PreferencesService preferencesService,
    required ScreenControlService screenControlService,
    required String sourceId,
  }) : _preferencesService = preferencesService,
       _screenControlService = screenControlService,
       _sourceId = sourceId,
       super(
         ReaderBrightnessState(
           brightnessOverride: _storedBrightness(
             preferencesService.readerBrightness,
           ),
           lastCustomBrightness: _clampBrightness(
             preferencesService.readerLastCustomBrightness,
           ),
         ),
       );

  static const double minBrightness = 0.05;
  static const double maxBrightness = 1.0;
  static const double defaultCustomBrightness = 0.7;

  final PreferencesService _preferencesService;
  final ScreenControlService _screenControlService;
  final String _sourceId;
  bool _active = false;

  void activate() {
    if (_active) return;
    _active = true;
    unawaited(_activate());
  }

  Future<void> _activate() async {
    await _clearLegacySourceBrightnessOverride();
    _refreshStoredBrightness();
    if (state.usesSystemBrightness) {
      await _resetPlatform();
      await _readPlatformBrightness();
      return;
    }
    await _readPlatformBrightness();
    await _syncPlatform();
  }

  Future<void> deactivate() async {
    if (!_active) return;
    _active = false;
    await _resetPlatform();
  }

  void previewBrightness(double value) {
    final nextValue = _clampBrightness(value);
    final next = ReaderBrightnessState(
      brightnessOverride: nextValue,
      lastCustomBrightness: nextValue,
      systemBrightness: state.systemBrightness,
    );
    if (state != next) emit(next);
    unawaited(_syncPlatform());
  }

  void commitBrightness(double value) {
    final nextValue = _clampBrightness(value);
    if (state.brightnessOverride != nextValue) {
      previewBrightness(nextValue);
    }
    unawaited(_storeCustomBrightness(nextValue));
  }

  Future<void> useSystemBrightness() async {
    await _clearLegacySourceBrightnessOverride();
    if (!state.usesSystemBrightness) {
      emit(
        ReaderBrightnessState(
          brightnessOverride: null,
          lastCustomBrightness: state.lastCustomBrightness,
          systemBrightness: state.systemBrightness,
        ),
      );
    }
    await _preferencesService.setReaderBrightness(null);
    await _resetPlatform();
    await _readPlatformBrightness();
  }

  void _refreshStoredBrightness() {
    if (isClosed) return;
    final next = ReaderBrightnessState(
      brightnessOverride: _storedBrightness(
        _preferencesService.readerBrightness,
      ),
      lastCustomBrightness: _clampBrightness(
        _preferencesService.readerLastCustomBrightness,
      ),
      systemBrightness: state.systemBrightness,
    );
    if (state != next) emit(next);
  }

  Future<void> _storeCustomBrightness(double value) async {
    await _preferencesService.setReaderBrightness(_clampBrightness(value));
  }

  Future<void> _clearLegacySourceBrightnessOverride() async {
    if (_preferencesService.readerBrightnessOverrideFor(_sourceId) == null) {
      return;
    }
    await _preferencesService.setReaderBrightnessOverride(_sourceId, null);
  }

  Future<void> _syncPlatform() {
    if (!_active) return Future<void>.value();
    final value = state.brightnessOverride;
    if (value == null) return _resetPlatform();
    return _setPlatformBrightness(value);
  }

  Future<void> _readPlatformBrightness() async {
    if (!_active || isClosed) return;
    try {
      final brightness = await _screenControlService
          .readApplicationBrightness();
      if (brightness == null || isClosed) return;
      final systemBrightness = _platformToControlBrightness(brightness);
      _logBrightness(
        'read-platform',
        platformBrightness: brightness,
        systemBrightness: systemBrightness,
      );
      final next = ReaderBrightnessState(
        brightnessOverride: state.brightnessOverride,
        lastCustomBrightness: state.lastCustomBrightness,
        systemBrightness: systemBrightness,
      );
      if (next == state) return;
      emit(next);
    } catch (e, st) {
      addError(e, st);
    }
  }

  Future<void> _setPlatformBrightness(double value) async {
    try {
      final platformBrightness = _controlToPlatformBrightness(value);
      _logBrightness(
        'set-platform',
        targetBrightness: value,
        platformBrightness: platformBrightness,
      );
      await _screenControlService.setApplicationBrightness(platformBrightness);
    } catch (e, st) {
      addError(e, st);
    }
  }

  Future<void> _resetPlatform() async {
    try {
      _logBrightness('reset-platform');
      await _screenControlService.resetApplicationBrightness();
    } catch (e, st) {
      addError(e, st);
    }
  }

  void _logBrightness(
    String event, {
    double? systemBrightness,
    double? targetBrightness,
    double? platformBrightness,
  }) {
    debugPrint(
      '[reader-brightness] $event '
      'mode=${state.usesSystemBrightness ? 'system' : 'custom'} '
      'widget=${_debugBrightness(state.controlValue)} '
      'system=${_debugBrightness(systemBrightness ?? state.systemBrightness)} '
      'override=${_debugBrightness(state.brightnessOverride)} '
      'last=${_debugBrightness(state.lastCustomBrightness)} '
      'target=${_debugBrightness(targetBrightness)} '
      'platform=${_debugBrightness(platformBrightness)}',
    );
  }

  static double? _storedBrightness(double? value) {
    if (value == null) return null;
    return _clampBrightness(value);
  }

  static double _clampBrightness(double value) =>
      value.clamp(minBrightness, maxBrightness).toDouble();

  static double _platformToControlBrightness(double value) =>
      value.clamp(0.0, 1.0).toDouble();

  static double _controlToPlatformBrightness(double value) =>
      _clampBrightness(value);

  static String _debugBrightness(double? value) {
    if (value == null) return 'null';
    return '${(value * 100).round()}% (${value.toStringAsFixed(3)})';
  }

  @override
  Future<void> close() async {
    if (_active) {
      await deactivate();
    }
    return super.close();
  }
}
