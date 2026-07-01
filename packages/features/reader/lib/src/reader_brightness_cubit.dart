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

  double get dimmingOpacity {
    final override = brightnessOverride;
    final system = systemBrightness;
    if (override == null || system == null || override >= system) return 0;
    return (1 - override / system).clamp(0.0, 0.9).toDouble();
  }

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
  static const double _buttonStep = 0.05;
  static const double _gridEpsilon = 0.000001;
  static const double _roundingScale = 100;

  final PreferencesService _preferencesService;
  final ScreenControlService _screenControlService;
  final String _sourceId;
  bool _active = false;
  int _lifecycleGeneration = 0;
  int _platformSyncRequest = 0;
  Future<void> _platformSyncQueue = Future<void>.value();

  Future<void> activate() {
    if (_active) return Future<void>.value();
    _active = true;
    final generation = ++_lifecycleGeneration;
    return _activate(generation);
  }

  Future<void> _activate(int generation) async {
    await _clearLegacySourceBrightnessOverride();
    if (!_isCurrentLifecycle(generation)) return;
    _refreshStoredBrightness();
    if (state.usesSystemBrightness) {
      await _readPlatformBrightness(generation);
      return;
    }
    await _readPlatformBrightness(generation);
    if (!_isCurrentLifecycle(generation)) return;
    await _queueCurrentPlatformSync();
  }

  Future<void> deactivate() async {
    if (!_active) return;
    _active = false;
    _lifecycleGeneration++;
    await _queuePlatformSync(
      const _ReaderBrightnessPlatformTarget.system(),
      force: true,
    );
  }

  void previewBrightness(double value) {
    final nextValue = _clampBrightness(value);
    final next = ReaderBrightnessState(
      brightnessOverride: nextValue,
      lastCustomBrightness: nextValue,
      systemBrightness: state.systemBrightness,
    );
    if (state != next) emit(next);
    unawaited(_queueCurrentPlatformSync());
  }

  void commitBrightness(double value) {
    final nextValue = _clampBrightness(value);
    if (state.brightnessOverride != nextValue) {
      previewBrightness(nextValue);
    }
    unawaited(_storeCustomBrightness(nextValue));
  }

  Future<void> changeBrightnessBy(double delta) async {
    final usesSystemBrightness = state.usesSystemBrightness;
    final knownBaseValue = _knownAdjustmentBaseBrightness();
    if (knownBaseValue != null) {
      _applyBrightnessDelta(
        knownBaseValue,
        delta,
        fromSystemBrightness: usesSystemBrightness,
      );
      return;
    }

    final baseValue = await _readAdjustmentBaseBrightness();
    if (!_active || isClosed) return;
    _applyBrightnessDelta(
      baseValue,
      delta,
      fromSystemBrightness: usesSystemBrightness,
    );
  }

  void _applyBrightnessDelta(
    double baseValue,
    double delta, {
    required bool fromSystemBrightness,
  }) {
    if (!_active || isClosed) return;
    final nextValue = _brightnessAfterDelta(
      baseValue,
      delta,
      fromSystemBrightness: fromSystemBrightness,
    );
    _logBrightness(
      'change-by',
      deltaBrightness: delta,
      targetBrightness: nextValue,
    );
    if (nextValue == state.controlValue) return;
    previewBrightness(nextValue);
    commitBrightness(nextValue);
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
    await _queuePlatformSync(const _ReaderBrightnessPlatformTarget.system());
    await _readPlatformBrightness(_lifecycleGeneration);
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

  Future<void> _queueCurrentPlatformSync() {
    return _queuePlatformSync(_platformTargetForState(state));
  }

  double? _knownAdjustmentBaseBrightness() {
    if (!state.usesSystemBrightness || state.systemBrightness != null) {
      return state.controlValue;
    }
    return null;
  }

  Future<double> _readAdjustmentBaseBrightness() async {
    if (!state.usesSystemBrightness || state.systemBrightness != null) {
      return state.controlValue;
    }

    final generation = _lifecycleGeneration;
    await _platformSyncQueue;
    if (!_isCurrentLifecycle(generation)) return state.controlValue;
    if (!state.usesSystemBrightness || state.systemBrightness != null) {
      return state.controlValue;
    }

    await _readPlatformBrightness(generation);
    if (!_isCurrentLifecycle(generation) || !state.usesSystemBrightness) {
      return state.controlValue;
    }
    return state.systemBrightness ?? state.controlValue;
  }

  Future<void> _queuePlatformSync(
    _ReaderBrightnessPlatformTarget target, {
    bool force = false,
  }) {
    if (!force && (!_active || isClosed)) return Future<void>.value();
    final request = ++_platformSyncRequest;
    _platformSyncQueue = _platformSyncQueue.then((_) async {
      if (request != _platformSyncRequest) return;
      if (!force && (!_active || isClosed)) return;
      await switch (target) {
        _ReaderBrightnessPlatformSystemTarget() => _resetPlatform(),
        _ReaderBrightnessPlatformCustomTarget(:final brightness) =>
          _setPlatformBrightness(brightness),
      };
    });
    return _platformSyncQueue;
  }

  Future<void> _readPlatformBrightness(int generation) async {
    if (!_isCurrentLifecycle(generation)) return;
    try {
      final brightness = await _screenControlService
          .readApplicationBrightness();
      if (brightness == null || !_isCurrentLifecycle(generation)) return;
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

  bool _isCurrentLifecycle(int generation) =>
      _active && !isClosed && _lifecycleGeneration == generation;

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
    double? deltaBrightness,
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
      'delta=${_debugSignedBrightness(deltaBrightness)} '
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

  static _ReaderBrightnessPlatformTarget _platformTargetForState(
    ReaderBrightnessState state,
  ) {
    final override = state.brightnessOverride;
    if (override == null) return const _ReaderBrightnessPlatformTarget.system();
    final system = state.systemBrightness;
    if (system != null && override <= system) {
      return const _ReaderBrightnessPlatformTarget.system();
    }
    return _ReaderBrightnessPlatformTarget.custom(override);
  }

  static double _brightnessAfterDelta(
    double value,
    double delta, {
    required bool fromSystemBrightness,
  }) {
    final current = _clampBrightness(value);
    if (delta > 0) return _nextBrightnessGridValue(current);
    if (delta < 0) {
      return _previousBrightnessGridValue(
        current,
        forceReadableStep: fromSystemBrightness,
      );
    }
    return _roundBrightness(current);
  }

  static double _nextBrightnessGridValue(double value) {
    final gridPosition = value / _buttonStep;
    final isOnGrid = (gridPosition - gridPosition.round()).abs() < _gridEpsilon;
    final nextGrid = isOnGrid ? gridPosition.round() + 1 : gridPosition.ceil();
    return _roundBrightness(_clampBrightness(nextGrid * _buttonStep));
  }

  static double _previousBrightnessGridValue(
    double value, {
    required bool forceReadableStep,
  }) {
    final gridPosition = value / _buttonStep;
    final isOnGrid = (gridPosition - gridPosition.round()).abs() < _gridEpsilon;
    var previousGrid = isOnGrid
        ? gridPosition.round() - 1
        : gridPosition.floor();
    if (forceReadableStep &&
        value - previousGrid * _buttonStep < _buttonStep / 2) {
      previousGrid -= 1;
    }
    return _roundBrightness(_clampBrightness(previousGrid * _buttonStep));
  }

  static double _roundBrightness(double value) {
    return (value * _roundingScale).roundToDouble() / _roundingScale;
  }

  static String _debugBrightness(double? value) {
    if (value == null) return 'null';
    return '${(value * 100).round()}% (${value.toStringAsFixed(3)})';
  }

  static String _debugSignedBrightness(double? value) {
    if (value == null) return 'null';
    final percent = value * 100;
    final sign = percent > 0 ? '+' : '';
    return '$sign${percent.toStringAsFixed(0)}% (${value.toStringAsFixed(3)})';
  }

  @override
  Future<void> close() async {
    if (_active) {
      await deactivate();
    }
    return super.close();
  }
}

sealed class _ReaderBrightnessPlatformTarget {
  const _ReaderBrightnessPlatformTarget();

  const factory _ReaderBrightnessPlatformTarget.system() =
      _ReaderBrightnessPlatformSystemTarget;

  const factory _ReaderBrightnessPlatformTarget.custom(double brightness) =
      _ReaderBrightnessPlatformCustomTarget;
}

final class _ReaderBrightnessPlatformSystemTarget
    extends _ReaderBrightnessPlatformTarget {
  const _ReaderBrightnessPlatformSystemTarget();
}

final class _ReaderBrightnessPlatformCustomTarget
    extends _ReaderBrightnessPlatformTarget {
  const _ReaderBrightnessPlatformCustomTarget(this.brightness);

  final double brightness;
}
